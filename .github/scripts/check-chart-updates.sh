#!/usr/bin/env bash
# Detect newer released chart versions for every public formula.yaml.
#
# Each public extension pins a Helm chart at
# spec.artifacts.chart.channels.<channel>.{ref,version}. Chart authors publish
# new versions to their OCI registry independently of this hub, so the pinned
# version drifts behind over time. This script lists the tags actually present
# in each chart's OCI repository and reports every channel whose pinned version
# is behind the newest published stable release.
#
# Gated and chart-less formulas (no spec.artifacts.chart) are skipped: there is
# no OCI artifact to compare against.
#
# Only stable X.Y.Z tags are considered upgrade targets. Pre-release tags
# (e.g. 0.2.0-rc1) and non-semver tags (latest, sha-…) are ignored so the bot
# never proposes bumping a published stable pin to a pre-release.
#
# Output: a JSON array on stdout, one object per channel that has an update:
#   [
#     {
#       "name": "cassandra",
#       "type": "provider",
#       "path": "extensions/providers/cassandra/formula.yaml",
#       "channel": "stable",
#       "ref": "oci://ghcr.io/openeverest/charts/provider-cassandra",
#       "current": "0.1.1",
#       "latest": "0.1.3"
#     }
#   ]
# Human-readable progress is written to stderr.
#
# Usage:
#   bash .github/scripts/check-chart-updates.sh            # JSON to stdout
#   bash .github/scripts/check-chart-updates.sh > updates.json
#
# Requires: yq (mikefarah, v4+), jq, oras (v1+), bash 4+.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EXT_DIR="${ROOT_DIR}/extensions"

log() { echo "$@" >&2; }

# Print the newest stable semver from stdin that is strictly greater than
# $current, or nothing if none is. Non-semver / pre-release tags are dropped.
# The pinned version is folded into the candidate set, so the max equals
# $current exactly when nothing newer exists (or the pin is ahead of the
# registry) — in which case nothing is printed and no downgrade is proposed.
newest_stable_gt() {
  local current="$1" newest
  newest=$(
    grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
      | { cat; echo "$current"; } \
      | sort -V -u \
      | tail -1
  )
  [[ "$newest" != "$current" ]] && echo "$newest"
}

mapfile -t formulas < <(
  find "$EXT_DIR/providers" "$EXT_DIR/plugins" \
    -mindepth 2 -maxdepth 2 -name formula.yaml 2>/dev/null | sort
)

updates=()

for f in "${formulas[@]}"; do
  name=$(yq '.metadata.name' "$f")
  type=$(yq '.metadata.type' "$f")
  rel_path="${f#"${ROOT_DIR}"/}"

  # Emit "channel<TAB>ref<TAB>version" per chart channel. Chart-less / gated
  # formulas produce no lines and are skipped.
  channels=$(yq '
    .spec.artifacts.chart.channels // {}
    | to_entries[]
    | [.key, .value.ref, .value.version]
    | join("\t")
  ' "$f")

  if [[ -z "$channels" ]]; then
    log "skip   $name (no chart artifact)"
    continue
  fi

  while IFS=$'\t' read -r channel ref current; do
    [[ -z "${ref:-}" ]] && continue

    repo="${ref#oci://}"
    log "check  $name [$channel] $repo (pinned $current)"

    if ! tags=$(oras repo tags "$repo" 2>/dev/null); then
      log "warn   $name [$channel]: could not list tags for $repo; skipping"
      continue
    fi

    latest=$(printf '%s\n' "$tags" | newest_stable_gt "$current")

    if [[ -z "$latest" || "$latest" == "$current" ]]; then
      log "ok     $name [$channel]: up to date at $current"
      continue
    fi

    log "update $name [$channel]: $current -> $latest"
    updates+=("$(jq -n \
      --arg name "$name" \
      --arg type "$type" \
      --arg path "$rel_path" \
      --arg channel "$channel" \
      --arg ref "$ref" \
      --arg current "$current" \
      --arg latest "$latest" \
      '{name:$name, type:$type, path:$path, channel:$channel, ref:$ref, current:$current, latest:$latest}')")
  done <<< "$channels"
done

if ((${#updates[@]} == 0)); then
  log "No chart updates available."
  echo "[]"
else
  printf '%s\n' "${updates[@]}" | jq -s '.'
fi
