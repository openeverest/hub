#!/usr/bin/env bash
# Generate index/index.json by reading every
# extensions/{providers,plugins,integrations}/*/formula.yaml and the OCI
# repository of every chart they point at.
#
# Output shape follows spec 005 §4.4. Phase-1 entries set verified=false and
# health=unknown (no healthcheck workflow yet).
#
# Every chart channel gains `head` (the formula's version) and `releases[]`:
# the published versions of the chart that belong to the channel, newest
# first, each with its manifest digest and what its Chart.yaml declares:
#
#   {"version": "0.6.0", "digest": "sha256:...",
#    "contractVersion": "2.0.0-alpha.1", "kubeVersion": ">=1.32.0-0"}
#
# contractVersion is the chart's `openeverest.io/contract-version`
# annotation: the version of the OpenEverest contract (CRDs, API, shared
# conventions) the chart was built against, written by the provider SDK.
# Installers compare it with the cluster so they can offer the newest
# compatible release rather than only the channel head. contractVersion and
# kubeVersion are omitted when the chart does not declare them. Both are read
# from the chart's OCI config blob, so no chart is downloaded.
#
# A channel's releases are the tags of its chart that are valid SemVer, not
# above the head, and a pre-release exactly when the head is one (see
# docs/PUBLISHING.md). Releases stamped with an invalid contract version, or
# with a development one (built against an unreleased OpenEverest), are left
# out with a warning.
#
# The previous index is the cache: a release whose digest is unchanged is not
# read again, and when a chart's registry cannot be reached its previous
# releases are kept, with a warning, instead of dropped.
#
# Every entry also records who publishes it (see lib/publisher.jq and
# docs/PUBLISHING.md): `publisher` is the GitHub account that owns the
# formula's sourceRepo, or else the ghcr.io namespace of its charts, and is
# omitted when neither is on GitHub; `thirdParty` is false only when the
# publisher is openeverest and every artifact is under ghcr.io/openeverest.
# Sources that disagree are reported with a warning.
#
# Output is deterministic for a given registry state: extensions are sorted by
# name, releases by SemVer precedence, and jq is invoked with --sort-keys.
#
# Usage:
#   bash .github/scripts/build-index.sh [--strict] [OUT]
#
#   OUT       output path (default: index/index.json); "-" writes to stdout.
#   --strict  exit non-zero when a channel head is unusable: its version is
#             not SemVer, or its contract stamp is invalid or a development
#             value. Pull requests run in this mode.
#
# Environment:
#   CRANE                 crane binary (default: crane)
#   HUB_JOBS              concurrent registry requests (default: 8)
#   HUB_OFFLINE=1         do not query registries; reuse the previous releases
#   HUB_PREVIOUS_INDEX    previous index (default: index/index.json)
#   HUB_REGISTRY_TIMEOUT  seconds allowed per registry request (default: 60)
#   HUB_ROOT_DIR          repository root (default: derived from this path)
#
# Requires: yq (mikefarah, v4+), jq 1.6+, crane, GNU xargs, bash 4+.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
ROOT_DIR="${HUB_ROOT_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
EXT_DIR="${ROOT_DIR}/extensions"

STRICT=false
OUT_PATH=""
for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=true ;;
    *) OUT_PATH="$arg" ;;
  esac
done
OUT_PATH="${OUT_PATH:-${ROOT_DIR}/index/index.json}"
PREV_INDEX="${HUB_PREVIOUS_INDEX:-${ROOT_DIR}/index/index.json}"
OFFLINE="${HUB_OFFLINE:-}"
JOBS="${HUB_JOBS:-8}"
export CRANE="${CRANE:-crane}"
export HUB_REGISTRY_TIMEOUT="${HUB_REGISTRY_TIMEOUT:-60}"

# Base URL used to expand relative `metadata.icon` paths into fully-qualified
# URLs in the generated index. Override via env var when building against a
# fork or a non-main ref.
HUB_RAW_BASE_URL="${HUB_RAW_BASE_URL:-https://raw.githubusercontent.com/openeverest/hub/main}"

log() { printf '%s\n' "$*" >&2; }

# annotate LEVEL FILE TEXT: a GitHub annotation in Actions, plain text elsewhere.
annotate() {
  local level=$1 file=$2 text=$3
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    printf '::%s%s::%s\n' "$level" "${file:+ file=$file}" "${text//%/%25}" >&2
  else
    printf '%s: %s\n' "$level" "$text" >&2
  fi
}

WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/build-index.XXXXXX")
export WORK_DIR
trap 'rm -rf "$WORK_DIR"' EXIT
mkdir -p "$WORK_DIR/tags" "$WORK_DIR/releases"

# ---------------------------------------------------------------------------
# Registry workers. Each runs in its own process (see run_parallel), reads one
# tab-separated job line prefixed with a job number, and writes one JSON
# document to $WORK_DIR/<kind>/<number>.json.
# ---------------------------------------------------------------------------

registry() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$HUB_REGISTRY_TIMEOUT" "$CRANE" "$@"
  else
    "$CRANE" "$@"
  fi
}

# error_text ERRFILE STATUS: the last line crane printed, or the exit status.
error_text() {
  local text
  text=$(grep -v '^[[:space:]]*$' "$1" 2>/dev/null | tail -n 1 | cut -c1-300 || true)
  if [[ -n "$text" ]]; then
    printf '%s' "$text"
  elif [[ "$2" == 124 ]]; then
    printf 'timed out after %ss' "$HUB_REGISTRY_TIMEOUT"
  else
    printf 'exit status %s' "$2"
  fi
}

# list_tags "<n>\t<ref>" -> {ref, ok, tags} or {ref, ok: false, error}
list_tags() {
  local n ref out tags rc=0
  IFS=$'\t' read -r n ref <<< "$1"
  out="$WORK_DIR/tags/$n"
  tags=$(registry ls "${ref#oci://}" 2>"$out.err") || rc=$?
  if (( rc == 0 )); then
    printf '%s\n' "$tags" \
      | jq -Rn --arg ref "$ref" '{ref: $ref, ok: true, tags: [inputs | select(length > 0)]}' > "$out.json"
  else
    jq -n --arg ref "$ref" --arg error "$(error_text "$out.err" "$rc")" \
      '{ref: $ref, ok: false, error: $error}' > "$out.json"
  fi
}

# fetch_release "<n>\t<ref>\t<tag>\t<version>\t<cachedDigest>"
#   -> {key, ok, digest, cached, contractVersion, kubeVersion} or {key, ok: false, error}
# The digest is always resolved, so a re-pushed tag is noticed; the chart
# metadata is only read when the digest differs from the cached one, and it
# is read by digest so both describe the same artifact.
fetch_release() {
  local n ref tag version cached out key digest config rc=0
  IFS=$'\t' read -r n ref tag version cached <<< "$1"
  out="$WORK_DIR/releases/$n"
  key="${ref}@${version}"

  digest=$(registry digest "${ref#oci://}:${tag}" 2>"$out.err") || rc=$?
  if (( rc != 0 )); then
    jq -n --arg key "$key" --arg error "$(error_text "$out.err" "$rc")" \
      '{key: $key, ok: false, error: $error}' > "$out.json"
    return 0
  fi

  if [[ -n "$cached" && "$digest" == "$cached" ]]; then
    jq -n --arg key "$key" --arg digest "$digest" \
      '{key: $key, ok: true, cached: true, digest: $digest}' > "$out.json"
    return 0
  fi

  config=$(registry config "${ref#oci://}@${digest}" 2>"$out.err") || rc=$?
  if (( rc != 0 )); then
    jq -n --arg key "$key" --arg error "$(error_text "$out.err" "$rc")" \
      '{key: $key, ok: false, error: $error}' > "$out.json"
    return 0
  fi

  if ! jq -c --arg key "$key" --arg digest "$digest" '
        def nonempty: if . == "" then null else . end;
        {key: $key, ok: true, cached: false, digest: $digest,
         contractVersion: ((.annotations // {})["openeverest.io/contract-version"] // null | nonempty),
         kubeVersion: (.kubeVersion // null | nonempty)}
      ' <<< "$config" > "$out.json" 2>/dev/null; then
    jq -n --arg key "$key" '{key: $key, ok: false, error: "chart metadata is not JSON"}' > "$out.json"
  fi
}

export -f registry error_text list_tags fetch_release

# run_parallel FUNC: run FUNC once per stdin line, $JOBS at a time.
run_parallel() {
  awk '{ printf "%d\t%s\n", NR, $0 }' \
    | xargs -r -d '\n' -n 1 -P "$JOBS" bash -c "$1 \"\$1\"" _ \
    || log "warning: some registry requests failed unexpectedly; affected releases fall back to the previous index"
}

# slurp_dir DIR JQ_FILTER: apply JQ_FILTER to the array of DIR/*.json documents.
slurp_dir() {
  local files=()
  shopt -s nullglob
  files=("$1"/*.json)
  shopt -u nullglob
  if (( ${#files[@]} )); then
    jq -s "$2" "${files[@]}"
  else
    jq -n "[] | $2"
  fi
}

# ---------------------------------------------------------------------------
# 1. Formulas -> index entries
# ---------------------------------------------------------------------------

# Use the latest commit timestamp (RFC3339) so re-running build doesn't churn
# the file when nothing has changed. Falls back to "now" outside git.
if generated_at=$(git -C "$ROOT_DIR" log -1 --pretty=%cI 2>/dev/null) && [[ -n "$generated_at" ]]; then
  :
else
  generated_at=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
fi

# Collect every formula.yaml under providers/, plugins/ and integrations/, sorted by path
# (which is by-slug because each lives under <type>/<slug>/formula.yaml).
mapfile -t formulas < <(
  find "$EXT_DIR/providers" "$EXT_DIR/plugins" "$EXT_DIR/integrations" \
    -mindepth 2 -maxdepth 2 -name formula.yaml 2>/dev/null | sort
)

# Convert each formula to a single-line JSON object describing the index entry.
# Per spec §4.4, `maturity` is always emitted (defaulting to "alpha" when the
# formula omits it) and `capabilities` is emitted verbatim only when non-empty.
entries=()
files=()
for f in "${formulas[@]}"; do
  rel_path="${f#${ROOT_DIR}/}"           # extensions/<type>/<slug>/formula.yaml
  rel_dir="${rel_path%/formula.yaml}"    # extensions/<type>/<slug>
  entry=$(yq -o=json -I=0 '
    {
      "name":         .metadata.name,
      "type":         .metadata.type,
      "displayName":  .metadata.displayName,
      "description":  .metadata.description,
      "categories":   (.metadata.categories // []),
      "keywords":     (.metadata.keywords // []),
      "homepage":     (.metadata.homepage // ""),
      "sourceRepo":   (.metadata.sourceRepo // ""),
      "license":      .metadata.license,
      "icon":         (.metadata.icon // ""),
      "maturity":     (.metadata.maturity // "alpha"),
      "maintainers":  (.metadata.maintainers // []),
      "verified":     false,
      "health":       "unknown",
      "capabilities": (.spec.capabilities // {}),
      "provider":     (.spec.provider // null),
      "plugin":       (.spec.plugin // null),
      "integration":  (.spec.integration // null),
      "access":       (.metadata.access // "public"),
      "gated":        (.spec.gated // null),
      "artifacts":    (.spec.artifacts // null),
      "install":      (.spec.install // null)
    }
  ' "$f" | jq -c \
    --arg base "$HUB_RAW_BASE_URL" \
    --arg dir "$rel_dir" '
      if (.icon == "" or .icon == null) then .icon = ""
      elif (.icon | test("^https?://")) then .
      else .icon = ($base + "/" + $dir + "/" + (.icon | sub("^\\./"; "")))
      end
      | if (.capabilities | length) == 0 then del(.capabilities) else . end
      | if (.gated == null) then del(.gated) else . end
      | if (.artifacts == null) then del(.artifacts) else . end
      | if (.install == null) then del(.install) else . end
    ')
  entries+=("$entry")
  files+=("$(jq -c --arg file "$rel_path" '{(.name): $file}' <<< "$entry")")
done

printf '%s\n' "${files[@]}" | jq -s 'add // {}' > "$WORK_DIR/files.json"
# Record who publishes each entry; see lib/publisher.jq.
printf '%s\n' "${entries[@]}" \
  | jq -s -L "$LIB_DIR" --slurpfile files "$WORK_DIR/files.json" \
      'include "publisher"; attribute_entries($files[0])' > "$WORK_DIR/publishers.json"
jq '.extensions' "$WORK_DIR/publishers.json" > "$WORK_DIR/entries.json"

# ---------------------------------------------------------------------------
# 2. Previous index -> release cache
# ---------------------------------------------------------------------------

if [[ -s "$PREV_INDEX" ]] && jq -e 'type == "object"' "$PREV_INDEX" >/dev/null 2>&1; then
  jq -L "$LIB_DIR" 'include "releases"; index_releases' "$PREV_INDEX" > "$WORK_DIR/cache.json"
else
  [[ -e "$PREV_INDEX" ]] && log "warning: $PREV_INDEX is not a valid index; building without a cache"
  echo '{}' > "$WORK_DIR/cache.json"
fi

# ---------------------------------------------------------------------------
# 3. Registry: list tags, then read every release that belongs to a channel
# ---------------------------------------------------------------------------

if [[ -n "$OFFLINE" ]]; then
  log "HUB_OFFLINE is set: registries not queried; chart channels keep the previous index's releases."
  echo '{}' > "$WORK_DIR/tags.json"
  echo '{}' > "$WORK_DIR/fetched.json"
else
  jq -r '[.[] | (.artifacts.chart.channels // {})[] | .ref] | unique[]' "$WORK_DIR/entries.json" \
    | run_parallel list_tags
  slurp_dir "$WORK_DIR/tags" 'map({key: .ref, value: .}) | from_entries' > "$WORK_DIR/tags.json"

  jq -r -L "$LIB_DIR" --slurpfile tags "$WORK_DIR/tags.json" --slurpfile cache "$WORK_DIR/cache.json" '
      include "releases";
      fetch_jobs($tags[0]; $cache[0])[] | [.ref, .tag, .version, .cachedDigest] | @tsv
    ' "$WORK_DIR/entries.json" > "$WORK_DIR/jobs.tsv"
  log "Reading $(wc -l < "$WORK_DIR/jobs.tsv" | tr -d ' ') chart release(s) from their registries."
  run_parallel fetch_release < "$WORK_DIR/jobs.tsv"
  slurp_dir "$WORK_DIR/releases" 'map({key: .key, value: .}) | from_entries' > "$WORK_DIR/fetched.json"
fi

# ---------------------------------------------------------------------------
# 4. Assemble
# ---------------------------------------------------------------------------

jq -L "$LIB_DIR" \
  --argjson strict "$STRICT" \
  --argjson offline "$([[ -n "$OFFLINE" ]] && echo true || echo false)" \
  --slurpfile tags "$WORK_DIR/tags.json" \
  --slurpfile fetched "$WORK_DIR/fetched.json" \
  --slurpfile cache "$WORK_DIR/cache.json" \
  --slurpfile files "$WORK_DIR/files.json" '
    include "releases";
    assemble({strict: $strict, offline: $offline, tags: $tags[0],
              fetched: $fetched[0], cache: $cache[0], files: $files[0]})
  ' "$WORK_DIR/entries.json" > "$WORK_DIR/assembled.json"

errors=0
while IFS=$'\t' read -r level file text; do
  [[ -z "$level" ]] && continue
  annotate "$level" "$file" "$text"
  [[ "$level" == "error" ]] && errors=$((errors + 1))
done < <(jq -r '.messages[] | [.level, .file, .text] | @tsv' "$WORK_DIR/publishers.json" "$WORK_DIR/assembled.json")

jq -r '.stats | "Listed releases for \(.channels) chart channel(s); \(.stampedHeads) channel head(s) carry an OpenEverest contract stamp."' \
  "$WORK_DIR/assembled.json" >&2
jq -r '.extensions | "\(map(select(.thirdParty | not)) | length) extension(s) published by OpenEverest, \(map(select(.thirdParty)) | length) third-party."' \
  "$WORK_DIR/publishers.json" >&2

# Stitch them together into the index document.
index_json=$(jq -n --sort-keys \
  --arg apiVersion "hub.openeverest.io/v1" \
  --arg kind "ExtensionIndex" \
  --arg catalogId "openeverest-official" \
  --arg generatedAt "$generated_at" \
  --arg schemaVersion "v1" \
  --slurpfile assembled "$WORK_DIR/assembled.json" '
    $assembled[0].extensions as $extensions
    | {
        apiVersion: $apiVersion,
        kind: $kind,
        metadata: {
          catalogId:        $catalogId,
          generatedAt:      $generatedAt,
          schemaVersion:    $schemaVersion,
          totalExtensions:  ($extensions | length)
        },
        extensions: ($extensions | sort_by(.name))
      }
  ')

if [[ "$OUT_PATH" == "-" ]]; then
  printf '%s\n' "$index_json"
else
  mkdir -p "$(dirname "$OUT_PATH")"
  printf '%s\n' "$index_json" > "$OUT_PATH"
  printf 'Wrote %s (%d extensions)\n' "$OUT_PATH" "${#entries[@]}" >&2
fi

if (( errors > 0 )); then
  log "$errors error(s): see above."
  exit 1
fi
