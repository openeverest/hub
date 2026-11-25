# Who publishes an extension, derived from its formula rather than declared in
# it, and whether that is OpenEverest itself. Installers and admins use this to
# tell extensions that follow OpenEverest's release process from third-party
# ones, so that a third-party extension cannot hold back a core upgrade.
#
# Load with: jq -L .github/scripts/lib 'include "publisher"; ...'

def official_publisher: "openeverest";

# The GitHub account that owns a github.com URL, lowercased because GitHub
# logins are case-insensitive. null for anything else, including other Git
# hosts: only GitHub accounts are compared with the openeverest organisation.
def github_owner:
  if type != "string" then null
  else (capture("^https?://(www\\.)?github\\.com/(?<owner>[A-Za-z0-9-]+)(/|$)"; "i").owner | ascii_downcase) // null
  end;

# The namespace of an oci://ghcr.io/<namespace>/... reference, lowercased.
# GHCR namespaces are GitHub accounts, so it can be compared with github_owner.
# null for other registries, whose namespaces are not GitHub accounts.
def ghcr_owner:
  if type != "string" then null
  else (capture("^oci://ghcr\\.io/(?<owner>[A-Za-z0-9-]+)/"; "i").owner | ascii_downcase) // null
  end;

# Input: one index entry. Yields {publisher, thirdParty, messages: [text]}.
#
# The publisher is the owner of metadata.sourceRepo on github.com or, failing
# that, the GHCR namespace of the entry's artifacts; null when neither is on
# GitHub. Both are written by the extension's author, so an entry counts as
# OpenEverest's own only when they agree: its publisher is openeverest and
# every artifact is published under ghcr.io/openeverest, where OpenEverest's
# release process pushes its charts. Anything else, including an unknown
# publisher, is third-party, and a disagreement is reported.
def attribute:
  (.sourceRepo | github_owner) as $source
  | [ (.artifacts // {})[] | (.channels // {})[] | .ref | select(type == "string") ]
  | unique
  | map({ref: ., owner: ghcr_owner}) as $artifacts
  | ($source // ([ $artifacts[] | .owner // empty ] | first)) as $publisher
  | ($publisher == official_publisher
     and all($artifacts[]; .owner == official_publisher)) as $official
  | (if $source != null then "metadata.sourceRepo (github.com/\($source))"
     else ($artifacts | map(select(.owner == $publisher)) | first | .ref) end) as $basis
  | { publisher: $publisher,
      thirdParty: ($official | not),
      messages: [
        $artifacts[]
        | if .owner != null and $publisher != null and .owner != $publisher then
            "publisher \"\($publisher)\" from \($basis) disagrees with \(.ref), published under ghcr.io/\(.owner); listed as third-party"
          elif .owner == null and $publisher == official_publisher then
            "\(.ref) is not published under ghcr.io/\(official_publisher), where OpenEverest publishes its charts; listed as third-party"
          else empty
          end ] };

# Input: the index entries. Adds publisher (omitted when unknown) and
# thirdParty to each. Yields {extensions, messages}.
#   $files: {"<name>": "<formula path>"}
def attribute_entries($files):
  map(. as $entry
      | attribute as $a
      | { entry: ($entry + {publisher: $a.publisher, thirdParty: $a.thirdParty}
                  | if .publisher == null then del(.publisher) else . end),
          messages: [ $a.messages[]
                      | {level: "warning", file: ($files[$entry.name] // ""), text: "\($entry.name): \(.)"} ] })
  | { extensions: map(.entry), messages: map(.messages[]) };
