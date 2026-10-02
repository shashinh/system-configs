# Zotero is held back to a pinned nixpkgs input.
#
# nixpkgs 2026-09-28 dropped the EOL firefox-esr-140 series and mechanically
# repointed zotero (10.0.2) at firefox-esr-153-unwrapped. Zotero 10.0.2 still
# requires Gecko 140.15.0esr (see its app/config.sh), and its fetch_xulrunner
# patch script aborts on 153 with:
#   AboutTranslations: \{ and ^  }, not found in modules/ActorManagerParent.sys.mjs
# so zotero does not build on the nixpkgs the shared lock tracks (verified
# 2026-10-01 at b4fd65b). The pin is the last nixpkgs both hosts ran before
# that change (nostromo's lock of 2026-09-23), which builds zotero 10.0.2
# against esr-140; both hosts get the same version they already had.
#
# TODO: drop this input and overlay once nixpkgs ships a zotero that builds
# against ESR 153 (check `nix build nixpkgs#zotero` after the next lock bump).
{ inputs, ... }:
{
  flake-file.inputs.nixpkgs-zotero.url = "github:NixOS/nixpkgs/4975466d324710c576dc11ad614684e6bd8cad8e";

  flake.modules.nixos.pc =
    { config, ... }:
    {
      nixpkgs.overlays = [
        (_: _: {
          zotero = inputs.nixpkgs-zotero.legacyPackages.${config.nixpkgs.hostPlatform.system}.zotero;
        })
      ];
    };
}
