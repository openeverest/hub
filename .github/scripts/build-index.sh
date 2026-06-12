#!/usr/bin/env bash
# Generate index/index.json by reading every extensions/{providers,plugins}/*/formula.yaml.
#
# Output shape follows spec 005 §4.4. Phase-1 entries set verified=false and
# health=unknown (no healthcheck workflow yet).
#
# Output is deterministic: extensions are sorted by name, and jq is invoked
# with --sort-keys so re-runs produce byte-identical output.
#
# Usage:
#   bash .github/scripts/build-index.sh            # writes to index/index.json
#   bash .github/scripts/build-index.sh -          # writes to stdout
#
# Requires: yq (mikefarah, v4+), jq, bash 4+.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EXT_DIR="${ROOT_DIR}/extensions"
OUT_PATH="${1:-${ROOT_DIR}/index/index.json}"

# Use the latest commit timestamp (RFC3339) so re-running build doesn't churn
# the file when nothing has changed. Falls back to "now" outside git.
if generated_at=$(git -C "$ROOT_DIR" log -1 --pretty=%cI 2>/dev/null) && [[ -n "$generated_at" ]]; then
  :
else
  generated_at=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
fi

# Collect every formula.yaml under providers/ and plugins/, sorted by path
# (which is by-slug because each lives under <type>/<slug>/formula.yaml).
mapfile -t formulas < <(
  find "$EXT_DIR/providers" "$EXT_DIR/plugins" \
    -mindepth 2 -maxdepth 2 -name formula.yaml 2>/dev/null | sort
)

# Convert each formula to a single-line JSON object describing the index entry.
# Per spec §4.4, `maturity` is always emitted (defaulting to "alpha" when the
# formula omits it) and `capabilities` is emitted verbatim only when non-empty.
entries=()
for f in "${formulas[@]}"; do
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
      "compatibility": .spec.compatibility,
      "capabilities": (.spec.capabilities // {}),
      "provider":     (.spec.provider // null),
      "plugin":       (.spec.plugin // null),
      "artifacts":    .spec.artifacts,
      "install":      .spec.install
    }
  ' "$f" | jq -c 'if (.capabilities | length) == 0 then del(.capabilities) else . end')
  entries+=("$entry")
done

# Stitch them together into the index document.
extensions_json=$(printf '%s\n' "${entries[@]}" | jq -s '.')

index_json=$(jq -n --sort-keys \
  --arg apiVersion "hub.openeverest.io/v1" \
  --arg kind "ExtensionIndex" \
  --arg catalogId "openeverest-official" \
  --arg generatedAt "$generated_at" \
  --arg schemaVersion "v1" \
  --argjson extensions "$extensions_json" '
    {
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
