#!/usr/bin/env bash
# Lint extensions/ for structural rules that aren't expressible in JSON Schema:
#   - Top-level subdirs of extensions/ are exactly: providers, plugins, _template, _deprecated
#   - Every extensions/{providers,plugins}/<name>/ contains formula.yaml + README.md
#   - <name> (directory) == metadata.name (formula)
#   - <name> appears in extensions/<type>/, where <type> matches metadata.type + 's'
#   - README.md is non-empty
#   - Only formula.yaml, README.md, logo.svg are allowed in an extension dir
#
# JSON Schema validation of each formula.yaml is run separately (see
# .github/workflows/validate.yaml).
#
# Requires: yq (mikefarah, v4+), bash 4+.
#
# Exit codes:
#   0 — all checks pass
#   1 — at least one check failed

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EXT_DIR="${ROOT_DIR}/extensions"

ALLOWED_TOP_LEVEL=(providers plugins _template _deprecated)
ALLOWED_FILES=(formula.yaml README.md logo.svg)

failures=0
fail() {
  printf 'FAIL: %s\n' "$*" >&2
  failures=$((failures + 1))
}
ok() {
  printf 'OK:   %s\n' "$*"
}

contains() {
  local needle=$1
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

# 1. Check top-level subdirs of extensions/
if [[ ! -d "$EXT_DIR" ]]; then
  fail "extensions/ directory not found at $EXT_DIR"
else
  for entry in "$EXT_DIR"/*/; do
    name=$(basename "$entry")
    if contains "$name" "${ALLOWED_TOP_LEVEL[@]}"; then
      ok "extensions/$name is an allowed top-level directory"
    else
      fail "extensions/$name is not an allowed top-level directory (allowed: ${ALLOWED_TOP_LEVEL[*]})"
    fi
  done
fi

# 2. Walk providers/ and plugins/ — _template and _deprecated are exempt.
for type_dir in providers plugins; do
  full_type_dir="$EXT_DIR/$type_dir"
  [[ -d "$full_type_dir" ]] || continue

  for ext_dir in "$full_type_dir"/*/; do
    [[ -d "$ext_dir" ]] || continue
    dir_name=$(basename "$ext_dir")
    rel_dir="extensions/$type_dir/$dir_name"

    formula="$ext_dir/formula.yaml"
    readme="$ext_dir/README.md"

    # 2a. Required files
    if [[ ! -f "$formula" ]]; then
      fail "$rel_dir/ missing formula.yaml"
      continue
    fi
    if [[ ! -f "$readme" ]]; then
      fail "$rel_dir/ missing README.md"
    elif [[ ! -s "$readme" ]]; then
      fail "$rel_dir/README.md is empty"
    fi

    # 2b. Only allowed files
    while IFS= read -r entry; do
      base=$(basename "$entry")
      if ! contains "$base" "${ALLOWED_FILES[@]}"; then
        fail "$rel_dir/$base is not an allowed file (allowed: ${ALLOWED_FILES[*]})"
      fi
    done < <(find "$ext_dir" -mindepth 1 -maxdepth 1 -type f)

    # 2c. metadata.name matches directory name
    meta_name=$(yq -r '.metadata.name // ""' "$formula")
    if [[ -z "$meta_name" ]]; then
      fail "$rel_dir/formula.yaml: metadata.name is missing or empty"
    elif [[ "$meta_name" != "$dir_name" ]]; then
      fail "$rel_dir/formula.yaml: metadata.name '$meta_name' must match directory name '$dir_name'"
    else
      ok "$rel_dir: name matches directory"
    fi

    # 2d. metadata.type matches parent directory (providers -> provider, plugins -> plugin)
    expected_type="${type_dir%s}"  # strip trailing 's'
    meta_type=$(yq -r '.metadata.type // ""' "$formula")
    if [[ "$meta_type" != "$expected_type" ]]; then
      fail "$rel_dir/formula.yaml: metadata.type '$meta_type' must be '$expected_type' (under extensions/$type_dir/)"
    else
      ok "$rel_dir: type matches parent directory"
    fi
  done
done

# 3. Global slug uniqueness across providers/ + plugins/
declare -A seen=()
while IFS= read -r f; do
  n=$(yq -r '.metadata.name // ""' "$f")
  [[ -z "$n" ]] && continue
  if [[ -n "${seen[$n]:-}" ]]; then
    fail "duplicate slug '$n' in $f and ${seen[$n]}"
  else
    seen[$n]=$f
  fi
done < <(find "$EXT_DIR/providers" "$EXT_DIR/plugins" -mindepth 2 -maxdepth 2 -name formula.yaml 2>/dev/null)

if (( failures > 0 )); then
  printf '\n%d check(s) failed.\n' "$failures" >&2
  exit 1
fi
printf '\nAll structural checks passed.\n'
