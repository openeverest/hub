#!/usr/bin/env bash
# Tests for build-index.sh and lib/releases.jq. Runs offline: a fake crane
# (fixtures/fake-crane) serves the charts described in fixtures/registry.json,
# and fixtures/hub is a miniature hub whose index/index.json plays the
# previous index.
#
# Usage:
#   bash .github/scripts/tests/build-index.test.sh
#
# Requires: yq (mikefarah, v4+), jq 1.6+, GNU xargs, bash 4+.

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${TEST_DIR}/.." && pwd)"
FIXTURES="${TEST_DIR}/fixtures"

WORK=$(mktemp -d "${TMPDIR:-/tmp}/build-index-test.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

failures=0
pass() { printf 'ok    %s\n' "$1"; }
fail() {
  printf 'FAIL  %s\n' "$1"
  failures=$((failures + 1))
}

# expect NAME EXPECTED ACTUAL
expect() {
  if [[ "$2" == "$3" ]]; then
    pass "$1"
  else
    fail "$1"
    printf '      expected: %s\n      actual:   %s\n' "$2" "$3"
  fi
}

# expect_line NAME FILE TEXT / expect_no_line NAME FILE TEXT
expect_line() {
  if grep -qF -- "$3" "$2"; then pass "$1"; else fail "$1"; printf '      missing: %s\n' "$3"; fi
}
expect_no_line() {
  if grep -qF -- "$3" "$2"; then fail "$1"; printf '      unexpected: %s\n' "$3"; else pass "$1"; fi
}

# lib EXPR: evaluate a jq expression with the releases library loaded.
lib() { jq -nc -L "${SCRIPTS_DIR}/lib" "include \"releases\"; $1"; }

# build NAME [ARGS...]: run the builder against the fixtures, writing
# $WORK/NAME.json, its stderr to $WORK/NAME.log and the crane calls to
# $WORK/NAME.calls. Prints the exit status.
build() {
  local name=$1 rc=0
  shift
  : > "$WORK/$name.calls"
  HUB_ROOT_DIR="${FIXTURES}/hub" \
    CRANE="${FIXTURES}/fake-crane" \
    FAKE_REGISTRY="${FIXTURES}/registry.json" \
    FAKE_CRANE_LOG="$WORK/$name.calls" \
    HUB_JOBS=4 \
    GITHUB_ACTIONS='' \
    bash "${SCRIPTS_DIR}/build-index.sh" "$@" "$WORK/$name.json" 2> "$WORK/$name.log" || rc=$?
  echo "$rc"
}

# releases NAME EXTENSION CHANNEL: the versions listed for a channel.
releases() {
  jq -c --arg ext "$2" --arg ch "$3" \
    '.extensions[] | select(.name == $ext) | .artifacts.chart.channels[$ch].releases | map(.version)' \
    "$WORK/$1.json"
}

# release NAME EXTENSION CHANNEL VERSION: one release object.
release() {
  jq -c --arg ext "$2" --arg ch "$3" --arg v "$4" \
    '.extensions[] | select(.name == $ext) | .artifacts.chart.channels[$ch].releases[] | select(.version == $v)' \
    "$WORK/$1.json"
}

echo "== SemVer"

ORDER='["2.0.0-alpha.1", "2.0.0-alpha.1.1", "2.0.0-alpha.1.dev", "2.0.0-alpha.2", "2.0.0-beta.1", "2.0.0-dev.4", "2.0.0-rc.1", "2.0.0", "2.0.1-dev", "2.0.1", "2.1.0-alpha.1"]'
expect "order vectors sort ascending" "true" \
  "$(lib "$ORDER as \$o | (\$o | reverse | sort_by(semver_key)) == \$o")"
expect "order vectors compare pairwise" "[-1]" \
  "$(lib "$ORDER as \$o | [range(0; (\$o | length) - 1) as \$i | semver_cmp(\$o[\$i]; \$o[\$i + 1])] | unique")"
expect "numeric identifiers compare numerically" "-1" "$(lib 'semver_cmp("1.0.0-rc.2"; "1.0.0-rc.10")')"
expect "build metadata does not change precedence" "0" "$(lib 'semver_cmp("1.0.0+a"; "1.0.0+b")')"
expect "invalid versions are rejected" "[]" \
  "$(lib '["", "v2.0.0", "2.0", "2", "2.0.0-", "02.0.0", "2.0.0-alpha..1", "2.0.0-01", "latest", ">=2.0.0", null, 2] | map(select(semver_valid))')"
expect "valid versions are accepted" "[]" \
  "$(lib '["0.0.0", "1.0.0-0", "1.0.0-0a", "1.0.0-x-y.z", "1.0.0+build.1", "1.0.0-rc.1+build.01"] | map(select(semver_valid | not))')"
expect "development values end in dev" '[true,true,false,false,false,false]' \
  "$(lib '["2.0.0-alpha.1.dev", "2.0.1-dev", "2.0.0-dev.4", "2.0.0", "2.0.0-alpha.1.dev.1", "latest"] | map(is_dev_version)')"

echo "== Channel membership"

expect "stable head collects stable tags up to the head" '["0.6.0","0.5.0+build.1","0.2.0"]' \
  "$(lib '["0.2.0", "0.6.0", "0.7.0", "0.6.0-rc.1", "latest", "sha-abc", "0.5.0_build.1"] | channel_versions("0.6.0")')"
expect "pre-release head collects pre-release tags up to the head" '["0.7.0-rc.2","0.7.0-rc.1","0.6.0-beta.1"]' \
  "$(lib '["0.6.0", "0.7.0-rc.1", "0.7.0-rc.2", "0.7.0-rc.10", "0.7.0", "0.6.0-beta.1"] | channel_versions("0.7.0-rc.2")')"
expect "non-SemVer head collects nothing" '[]' "$(lib '["0.1.0"] | channel_versions("latest")')"

echo "== Build"

expect "build exits 0" "0" "$(build first)"
expect "every formula is indexed" "6" "$(jq '.extensions | length' "$WORK/first.json")"
expect "no hand-written compatibility is emitted" "0" \
  "$(jq '[.extensions[] | select(has("compatibility"))] | length' "$WORK/first.json")"
expect "channel keeps ref and version, gains head" \
  '{"head":"0.3.0","ref":"oci://registry.test/charts/alpha","version":"0.3.0"}' \
  "$(jq -c '.extensions[] | select(.name == "alpha") | .artifacts.chart.channels.stable | del(.releases)' "$WORK/first.json")"
expect "stable releases: SemVer tags up to the head, newest first" '["0.3.0","0.2.1+build.7","0.2.0"]' \
  "$(releases first alpha stable)"
expect "stamp and kubeVersion are read from the chart metadata" \
  '{"contractVersion":"2.0.0-alpha.2","digest":"sha256:alpha-0.3.0","kubeVersion":">=1.32.0-0","version":"0.3.0"}' \
  "$(release first alpha stable 0.3.0)"
expect "unstamped release omits contractVersion and kubeVersion" \
  '{"digest":"sha256:alpha-0.2.0","version":"0.2.0"}' "$(release first alpha stable 0.2.0)"
expect_line "build metadata is read from its OCI tag" "$WORK/first.calls" "digest registry.test/charts/alpha:0.2.1_build.7"
expect_line "a re-pushed tag is read again" "$WORK/first.calls" "config registry.test/charts/alpha@sha256:alpha-0.3.0"
expect_no_line "an unchanged digest is served from the previous index" "$WORK/first.calls" "config registry.test/charts/alpha@sha256:alpha-0.2.0"
expect_no_line "tags above the head are not read" "$WORK/first.calls" "registry.test/charts/alpha:0.4.0"
expect_no_line "pre-release tags are not read for a stable head" "$WORK/first.calls" "registry.test/charts/alpha:0.3.0-rc.1"
expect_line "a development stamp is left out" "$WORK/first.log" \
  "warning: alpha [stable]: 0.1.0 was built against an unreleased OpenEverest (2.0.0-alpha.1.dev); left out of the index"

expect "unreachable registry keeps the previous releases up to the head" '["1.0.0","0.9.0"]' "$(releases first bravo stable)"
expect "kept releases keep their data" \
  '{"contractVersion":"2.0.0-alpha.1","digest":"sha256:bravo-1.0.0","kubeVersion":">=1.32.0-0","version":"1.0.0"}' \
  "$(release first bravo stable 1.0.0)"
expect_line "unreachable registry warns" "$WORK/first.log" \
  "warning: bravo [stable]: could not list the tags of oci://registry.test/charts/bravo"

expect "stable channel skips pre-releases" '["0.1.0"]' "$(releases first charlie stable)"
expect "edge channel lists pre-releases up to the head" '["0.2.0-rc.2","0.1.0-beta.1"]' "$(releases first charlie edge)"
expect "a release that cannot be read keeps the previous data" \
  '{"digest":"sha256:charlie-0.1.0-beta.1","kubeVersion":">=1.30.0-0","version":"0.1.0-beta.1"}' \
  "$(release first charlie edge 0.1.0-beta.1)"
expect_line "unreadable release with previous data warns" "$WORK/first.log" \
  "warning: charlie [edge]: could not read 0.1.0-beta.1"
expect_line "unreadable release without previous data is left out" "$WORK/first.log" \
  "warning: charlie [edge]: could not read 0.2.0-rc.1 (Error: GET https://registry.test/v2/charts/charlie/manifests/0.2.0-rc.1: 503 Service Unavailable); left out of the index"
expect_line "a head without kubeVersion warns" "$WORK/first.log" \
  "warning: charlie [stable]: 0.1.0 declares no kubeVersion in Chart.yaml"
expect_no_line "a head with kubeVersion does not warn" "$WORK/first.log" "charlie [edge]: 0.2.0-rc.2 declares no kubeVersion"

expect "gated entry has no artifacts" "false" \
  "$(jq '.extensions[] | select(.name == "delta") | has("artifacts")' "$WORK/first.json")"

expect "dev-stamped head and invalid stamps are left out" '["0.8.0"]' "$(releases first echo stable)"
expect_line "dev-stamped head warns" "$WORK/first.log" \
  "warning: echo [stable]: 1.0.0 was built against an unreleased OpenEverest (2.0.1-dev)"
expect_line "invalid stamp warns" "$WORK/first.log" \
  'warning: echo [stable]: 0.9.0 carries an invalid openeverest.io/contract-version ">=2.0.0"'
expect "non-SemVer head lists no releases" '[]' "$(releases first foxtrot stable)"
expect_line "non-SemVer head warns" "$WORK/first.log" \
  'warning: foxtrot [stable]: version "latest" is not a SemVer 2.0.0 version'

echo "== Rebuild from the new index"

cp "$WORK/first.json" "$WORK/previous.json"
expect "rebuild exits 0" "0" "$(HUB_PREVIOUS_INDEX="$WORK/previous.json" build second)"
expect "rebuild is byte-identical" "$(sha256sum < "$WORK/first.json")" "$(sha256sum < "$WORK/second.json")"
expect "rebuild only reads metadata it could not cache" \
  '["config registry.test/charts/alpha@sha256:alpha-0.1.0","config registry.test/charts/echo@sha256:echo-0.9.0","config registry.test/charts/echo@sha256:echo-1.0.0"]' \
  "$(grep '^config ' "$WORK/second.calls" | sort | jq -Rcs 'split("\n") | map(select(length > 0))')"

echo "== Strict mode"

expect "strict build fails" "1" "$(build strict --strict)"
expect_line "strict: dev-stamped head is an error" "$WORK/strict.log" \
  "error: echo [stable]: 1.0.0 was built against an unreleased OpenEverest (2.0.1-dev)"
expect_line "strict: non-SemVer head is an error" "$WORK/strict.log" \
  'error: foxtrot [stable]: version "latest" is not a SemVer 2.0.0 version'
expect_line "strict: older releases only warn" "$WORK/strict.log" \
  "warning: echo [stable]: 0.9.0 carries an invalid"
expect "strict: the index is still written" "6" "$(jq '.extensions | length' "$WORK/strict.json")"

echo "== Offline"

expect "offline build exits 0" "0" "$(HUB_OFFLINE=1 build offline)"
expect "offline build makes no registry calls" "0" "$(wc -l < "$WORK/offline.calls" | tr -d ' ')"
expect "offline build keeps the previous releases" '["0.3.0","0.2.0"]' "$(releases offline alpha stable)"
expect_no_line "offline build does not warn per channel" "$WORK/offline.log" "could not list the tags"

echo
if (( failures > 0 )); then
  echo "$failures test(s) failed."
  exit 1
fi
echo "All tests passed."
