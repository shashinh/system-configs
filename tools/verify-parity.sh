#!/usr/bin/env bash
# Compares the current evaluation of both hosts against the captured baseline
# drvPaths in ../baselines (relative to the repo checkout during the refactor).
# Identical drvPaths == functionally equivalent configuration.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
base="${BASELINE_DIR:-$root/../baselines}"

fail=0
for h in serenity nostromo; do
  cur=$(nix eval --raw "$root#nixosConfigurations.$h.config.system.build.toplevel.drvPath")
  want=$(head -n1 "$base/$h.drvPath")
  if [ "$cur" = "$want" ]; then
    echo "PASS $h  $cur (drvPath identical)"
  else
    # Tier 2: accept differences that are provably reorderings of identical
    # multisets (list-typed NixOS options merge in module order; the module
    # graph shape changes that order without changing the configuration).
    if "$root/tools/drv-equiv.sh" "$want" "$cur"; then
      echo "PASS $h  $cur (equivalent; reorderings only)"
    else
      echo "FAIL $h"
      echo "  want $want"
      echo "  got  $cur"
      echo "  diagnose: nix run nixpkgs#nix-diff -- $want $cur"
      fail=1
    fi
  fi
done
exit $fail
