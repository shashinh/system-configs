# Home-manager half of the plasma feature: seeds the KDE user configuration
# backed up under dotfiles/kde/ (taken from serenity on 2026-10-01, text
# files only) into the home directory, so an emergency revert to Plasma
# comes back with the desktop as it was: look-and-feel, kwin rules and
# tiling script, shortcuts, panels, app settings.
#
# Files are COPIED, never linked and never overwritten (cp -Rn): KDE rewrites
# these files constantly and must own them. Delete a file from $HOME to have
# it re-seeded on the next activation. Nothing is removed when the feature
# is dropped again.
#
# Requires the host to enable home-manager (import `home-shashin`).
{ inputs, ... }:
{
  flake.modules.nixos.plasma = {
    home-manager.sharedModules = [ inputs.self.modules.homeManager.plasma ];
  };

  flake.modules.homeManager.plasma =
    { config, lib, pkgs, ... }:
    let
      src = "${config.dotfiles.repoPath}/dotfiles/kde";
    in
    {
      home.activation.seedKdeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ -d "${src}" ]; then
          for sub in .config .local/share; do
            if [ -d "${src}/$sub" ]; then
              run mkdir -p "$HOME/$sub"
              run ${pkgs.coreutils}/bin/cp -Rn "${src}/$sub/." "$HOME/$sub/"
            fi
          done
        else
          echo "plasma: ${src} not found; KDE config not seeded" >&2
        fi
      '';
    };
}
