# Release rules shared by build-index.sh and its tests: strict SemVer 2.0.0
# parsing and precedence, channel membership, and the assembly of each chart
# channel's `releases[]` from what the registry returned.
#
# Load with: jq -L .github/scripts/lib 'include "releases"; ...'

# ---------------------------------------------------------------------------
# SemVer 2.0.0
# ---------------------------------------------------------------------------

# Parse a strict SemVer 2.0.0 string into {major, minor, patch, pre, build}.
# Yields null for anything else: a "v" prefix, partial versions such as "2.0",
# empty identifiers, or numeric identifiers with leading zeros.
def semver_parse:
  if type != "string" then null
  else
    (capture("^(?<major>0|[1-9][0-9]*)\\.(?<minor>0|[1-9][0-9]*)\\.(?<patch>0|[1-9][0-9]*)(-(?<pre>[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*))?(\\+(?<build>[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*))?$") // null)
    | if . == null then null
      else
        ((.pre // "") | if . == "" then [] else split(".") end) as $pre
        | if any($pre[]; test("^0[0-9]+$")) then null
          else {
            major: (.major | tonumber),
            minor: (.minor | tonumber),
            patch: (.patch | tonumber),
            pre: $pre,
            build: (.build // "")
          }
          end
      end
  end;

def semver_valid: semver_parse != null;

# A sort key that orders valid versions by SemVer precedence under jq's own
# ordering: numbers sort before strings, so numeric pre-release identifiers
# rank below alphanumeric ones; a release ([1]) ranks above its pre-releases
# ([0, ...]); and an identifier list ranks below a longer one it is a prefix
# of. Build metadata does not take part, as SemVer requires.
def semver_key:
  semver_parse
  | [ .major, .minor, .patch,
      (if (.pre | length) == 0 then [1]
       else [0] + (.pre | map(if test("^[0-9]+$") then tonumber else . end))
       end) ];

def semver_cmp($a; $b):
  ($a | semver_key) as $x
  | ($b | semver_key) as $y
  | if $x < $y then -1 elif $x > $y then 1 else 0 end;

def is_prerelease: (semver_parse.pre // []) | length > 0;

# A development value: what core's main branch carries between releases. It
# sorts after the last release R and before any release that can follow R:
# - after a pre-release, R.next (2.0.0-alpha.1.next): SemVer fits only
#   R.<more> between two pre-releases, which is also how Go pseudo-versions
#   and Kubernetes CI builds write a build after a pre-release. The marker is
#   "next", not "dev": "dev" means "before" to PEP 440 and Maven, and
#   2.0.0-dev.N are real releases, so they are not development values;
# - after a release, the next minor's alpha.0 (2.1.0-alpha.0): main builds
#   the next minor, and Kubernetes tags master the same way at each
#   release-branch cut. No release is ever named alpha.0.
# A chart stamped with one was built against an unreleased core.
def is_development:
  semver_parse as $v
  | $v != null and (($v.pre | last) == "next" or $v.pre == ["alpha", "0"]);

# OCI tags cannot contain "+", so Helm pushes chart 1.0.0+build as tag
# 1.0.0_build.
def tag_to_version: gsub("_"; "+");
def version_to_tag: gsub("\\+"; "_");

# ---------------------------------------------------------------------------
# Channels
# ---------------------------------------------------------------------------

# The input is a list of OCI tags. Yields the versions that belong to a
# channel whose head is $head, newest first: valid SemVer, not above the head,
# and a pre-release exactly when the head is one. A stable head therefore
# never collects release candidates, and an edge head never collects stable
# releases. Tags that are not SemVer (latest, sha-...) are ignored.
def channel_versions($head):
  if ($head | semver_valid | not) then []
  else
    ($head | semver_key) as $hk
    | ($head | is_prerelease) as $hp
    | map(tag_to_version | select(semver_valid))
    | map(select((semver_key <= $hk) and (is_prerelease == $hp)))
    | unique
    | sort_by(semver_key, .)
    | reverse
  end;

# ---------------------------------------------------------------------------
# Index assembly
# ---------------------------------------------------------------------------

def contract_annotation: "openeverest.io/contract-version";

def release_key($ref; $version): "\($ref)@\($version)";

# Every release recorded in an index document, keyed by release_key. This is
# the cache: a release whose digest has not changed is not read again.
def index_releases:
  reduce (
    (.extensions // [])[]
    | (.artifacts.chart.channels // {})[]
    | .ref as $ref
    | (.releases // [])[]
    | {key: release_key($ref; .version), value: .}
  ) as $r ({}; .[$r.key] = $r.value);

# Input: the index entries. Yields one fetch job per distinct ref@version
# across the chart channels whose tags could be listed:
# [{ref, tag, version, cachedDigest}].
#   $tags:  {"<ref>": {ok, tags: [...]}} from the registry
#   $cache: index_releases of the previous index
def fetch_jobs($tags; $cache):
  [ .[]
    | (.artifacts.chart.channels // {})[]
    | .ref as $ref
    | .version as $head
    | select($tags[$ref].ok == true)
    | $tags[$ref].tags
    | channel_versions($head)[]
    | { ref: $ref,
        tag: version_to_tag,
        version: .,
        cachedDigest: ($cache[release_key($ref; .)].digest // "") } ]
  | unique_by(release_key(.ref; .version));

def drop_nulls: with_entries(select(.value != null));

# Input: one chart channel ({ref, version}). Yields {channel, messages}.
#   $ctx: {name, file, channelName, strict, offline, tags, fetched, cache}
def resolve_channel($ctx):
  . as $ch
  | $ch.ref as $ref
  | $ch.version as $head
  | ($ctx.tags[$ref] // {ok: false, error: "registry not queried"}) as $listing
  | "\($ctx.name) [\($ctx.channelName)]" as $label
  | (if $ctx.strict then "error" else "warning" end) as $headLevel
  | def msg($level; $text): {level: $level, file: $ctx.file, text: "\($label): \($text)"};

    if ($head | semver_valid | not) then
      { channel: ($ch + {head: $head, releases: []}),
        messages: [msg($headLevel; "version \"\($head)\" is not a SemVer 2.0.0 version; no releases listed")] }
    elif $listing.ok != true then
      # Registry unreachable: keep what the previous index knew about this
      # chart rather than publishing an index without it.
      ([ $ctx.cache | to_entries[]
         | select(.key | startswith("\($ref)@"))
         | .value ]) as $known
      | ($known | map(.version) | channel_versions($head)) as $keep
      | { channel: ($ch + {head: $head,
                           releases: [$keep[] as $v | $known[] | select(.version == $v)]}),
          messages: (if $ctx.offline then []
                     else [msg("warning"; "could not list the tags of \($ref) (\($listing.error // "unknown error")); kept \($keep | length) release(s) from the previous index")]
                     end) }
    else
      ($listing.tags | channel_versions($head)) as $versions
      | [ $versions[] as $v
          | release_key($ref; $v) as $key
          | ($ctx.fetched[$key] // {ok: false, error: "not fetched"}) as $f
          | if $f.ok == true and $f.cached == true then
              {release: $ctx.cache[$key]}
            elif $f.ok == true then
              {release: ({version: $v, digest: $f.digest,
                          contractVersion: $f.contractVersion,
                          kubeVersion: $f.kubeVersion} | drop_nulls)}
            elif $ctx.cache[$key] != null then
              {release: $ctx.cache[$key],
               message: msg("warning"; "could not read \($v) (\($f.error // "unknown error")); kept the previous index's data for it")}
            else
              {message: msg("warning"; "could not read \($v) (\($f.error // "unknown error")); left out of the index")}
            end ] as $resolved
      | [ $resolved[] | .release // empty ] as $candidates
      | [ $candidates[]
          | . as $r
          | (if $r.version == $head then $headLevel else "warning" end) as $level
          | if $r.contractVersion == null then {release: $r}
            elif ($r.contractVersion | semver_valid | not) then
              {message: msg($level; "\($r.version) carries an invalid \(contract_annotation) \"\($r.contractVersion)\" (not SemVer 2.0.0); left out of the index")}
            elif ($r.contractVersion | is_development) then
              {message: msg($level; "\($r.version) was built against an unreleased OpenEverest (\($r.contractVersion)); left out of the index. Publish a chart built against a released OpenEverest")}
            else {release: $r}
            end ] as $checked
      | ($candidates | map(select(.version == $head)) | first) as $headRelease
      | { channel: ($ch + {head: $head, releases: [$checked[] | .release // empty]}),
          messages: (
            [ $resolved[] | .message // empty ]
            + [ $checked[] | .message // empty ]
            + (if ($versions | index($head)) == null then
                 [msg("warning"; "\($head) is not published in \($ref)")]
               else [] end)
            + (if $headRelease != null and $headRelease.kubeVersion == null then
                 [msg("warning"; "\($head) declares no kubeVersion in Chart.yaml; set a lower bound such as \">=1.32.0-0\"")]
               else [] end)) }
    end;

# Input: the index entries. Adds head and releases[] to every chart channel.
# Yields {extensions, messages, stats}.
#   $opts: {strict, offline, tags, fetched, cache, files: {"<name>": "<path>"}}
def assemble($opts):
  [ .[]
    | . as $entry
    | if (.artifacts.chart.channels // null) == null then {entry: $entry, results: []}
      else
        [ .artifacts.chart.channels | to_entries[]
          | .key as $channelName
          | {name: $channelName}
            + (.value | resolve_channel($opts + {name: $entry.name,
                                                 file: ($opts.files[$entry.name] // ""),
                                                 channelName: $channelName})) ] as $results
        | {entry: (.artifacts.chart.channels = ($results | map({key: .name, value: .channel}) | from_entries)),
           results: $results}
      end ] as $done
  | { extensions: [ $done[].entry ],
      messages: [ $done[].results[].messages[] ],
      stats: {
        channels: ([ $done[].results[] ] | length),
        stampedHeads: ([ $done[].results[].channel
                         | .head as $h
                         | .releases[]
                         | select(.version == $h and .contractVersion != null) ] | length)
      } };
