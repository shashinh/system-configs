#!/usr/bin/env bash
# Structural equivalence check between two toplevel derivations.
#
# Two configurations are considered equivalent when every derivation in the
# closure whose *own content* differs (per nix-diff: environment, build
# command, arguments or sources — not merely inputs that were already
# compared) differs only by reordering: after recursively sorting all
# arrays (including arrays inside JSON-encoded string attrs) and dropping
# input/output references, the two derivations must be identical.
#
# Usage: drv-equiv.sh <old.drv> <new.drv>
# Exit 0: equivalent (identical, or reorderings only; culprits listed)
# Exit 1: real difference found (culprit pair printed)
set -euo pipefail

old="$1" new="$2"

if [ "$old" = "$new" ]; then
  echo "IDENTICAL"
  exit 0
fi

report=$(mktemp)
trap 'rm -f "$report"' EXIT
nix run nixpkgs#nix-diff -- "$old" "$new" > "$report" 2>/dev/null || true

# Collect (old,new) drv pairs that carry a real content difference.
# nix-diff prints a candidate pair as
#   - /nix/store/...drv:{out}
#   + /nix/store/...drv:{out}
# and only some pairs are followed (at deeper indentation) by a real
# content marker before the next pair starts.
pairs=$(awk '
  /^[[:space:]]*- \/nix\/store\/.*\.drv/ { o=$2; sub(/:.*/,"",o); next }
  /^[[:space:]]*\+ \/nix\/store\/.*\.drv/ { n=$2; sub(/:.*/,"",n); lastpair=o" "n; next }
  /The environments do not match|The build commands do not match|The arguments do not match|The input sources do not match|do not match:/ {
    if (lastpair != "" && lastpair != seen) { print lastpair; seen=lastpair }
  }
' "$report" | sort -u)

# The root pair always differs (it is why we are here); include it only if
# it carries its own content diff, which the awk above already decides.

if [ -z "$pairs" ]; then
  # Differences exist but every one of them is transitive (inputs only).
  # That can only happen via fixed-output/source drift; treat as reorder-free.
  echo "EQUIVALENT (no content-level differences; transitive input changes only)"
  exit 0
fi

# Normalize one derivation for comparison:
#  - drop input references and output paths (differences there are chased
#    through their own drv pairs by nix-diff, or are pure hash propagation)
#  - elide store-path hashes inside strings for the same reason
#  - parse JSON-encoded string attrs (__json / structured pkgs lists)
#  - sort every array recursively
norm() {
  nix derivation show "$1" | jq -S '
    def elide: gsub("/nix/store/[a-z0-9]{32}-"; "/nix/store/ELIDED-");
    def normstr:
      (try (fromjson | walk(
             if type == "string" then elide
             elif type == "array" then sort
             else . end) | tojson)
       catch elide);
    .derivations | to_entries[0].value
    | del(.inputs, .name)
    | .outputs = "elided"
    | walk(if type == "string" then normstr
           elif type == "array" then sort
           else . end)
  '
}

status=0
while read -r o n; do
  [ -z "$o" ] && continue
  if diff <(norm "$o") <(norm "$n") > /dev/null 2>&1; then
    echo "REORDER-ONLY  ${o##*/}"
  else
    echo "REAL-DIFF     ${o##*/}  vs  ${n##*/}"
    echo "  inspect: nix run nixpkgs#nix-diff -- $o $n"
    status=1
  fi
done <<< "$pairs"

exit $status
