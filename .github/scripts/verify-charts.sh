#!/usr/bin/env bash
# Verify that every Helm chart artifact referenced by a formula.yaml actually
# exists in its OCI registry at the declared version.
#
# The hub renders install instructions from spec.artifacts.chart.channels.*.ref
# and .version, so a typo or an unpublished/yanked version would hand users a
# `helm install` command that fails. This check confirms each referenced chart
# is pullable before we advertise it.
#
# Extensions without a chart artifact (gated / URL-less entries such as mssql)
# are skipped: there is nothing to verify.
#
# Usage:
#   bash .github/scripts/verify-charts.sh
#
# Requires: yq (mikefarah, v4+), helm 3.8+ (OCI support). Exits non-zero if any
# referenced chart cannot be resolved.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EXT_DIR="${ROOT_DIR}/extensions"

mapfile -t formulas < <(
  find "$EXT_DIR/providers" "$EXT_DIR/plugins" "$EXT_DIR/integrations" \
    -mindepth 2 -maxdepth 2 -name formula.yaml 2>/dev/null | sort
)

checked=0
skipped=0
failed=0
failures=()

for f in "${formulas[@]}"; do
  name=$(yq '.metadata.name' "$f")

  # Emit one "channel<TAB>ref<TAB>version" line per chart channel. Formulas
  # without spec.artifacts.chart (gated, frontend-only, or template) produce
  # no lines and are skipped.
  channels=$(yq '
    .spec.artifacts.chart.channels // {}
    | to_entries[]
    | [.key, .value.ref, .value.version]
    | join("\t")
  ' "$f")

  if [[ -z "$channels" ]]; then
    echo "skip   $name (no chart artifact)"
    skipped=$((skipped + 1))
    continue
  fi

  while IFS=$'\t' read -r channel ref version; do
    [[ -z "${ref:-}" ]] && continue
    checked=$((checked + 1))
    label="$name [$channel] ${ref}:${version}"
    echo "::group::verify $label"
    if out=$(helm show chart "$ref" --version "$version" 2>&1); then
      echo "ok     $label"
    else
      echo "$out"
      echo "::error file=${f#${ROOT_DIR}/}::Chart could not be resolved: $ref version $version"
      failures+=("$label")
      failed=$((failed + 1))
    fi
    echo "::endgroup::"
  done <<< "$channels"
done

echo
echo "Verified $checked chart reference(s); skipped $skipped extension(s) with no chart."

if (( failed > 0 )); then
  echo "::error::$failed chart reference(s) could not be resolved:"
  for item in "${failures[@]}"; do
    echo "  - $item"
  done
  exit 1
fi

echo "All referenced charts resolved successfully."
