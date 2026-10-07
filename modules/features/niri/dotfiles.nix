# niri's configuration, vendored under dotfiles/ and linked back into
# ~/.config/niri as OUT-OF-STORE symlinks, so edits apply on niri's next
# config reload without a rebuild and land in the checkout as uncommitted
# changes.
#
# Shared config, per-host fragment, composed by niri's own `include`:
#
#   dotfiles/niri/.config/niri/config.kdl    portable: layout, keybinds,
#                                            window rules. Contains
#                                              include optional=true "noctalia.kdl"
#                                              include "host.kdl"
#   dotfiles/niri/hosts/<hostname>/host.kdl  everything display- or
#                                            hardware-bound: output blocks,
#                                            default/preset column widths,
#                                            laptop input devices, host-only
#                                            binds
#
# noctalia.kdl (accent/border colours) is NOT vendored or linked. Noctalia's
# niri theme template regenerates it on every palette change (every wallpaper
# change), so a vendored copy was permanently dirty. It is a plain
# machine-local file at ~/.config/niri/noctalia.kdl, written by noctalia, and
# config.kdl includes it with `optional=true`: a missing file is a warning,
# not an error (verified with `niri validate`, niri 26.04). Noctalia's
# post-hook (assets/templates/niri/apply.sh) recognises the optional include
# line as its own, so it does not append a second, required one to config.kdl.
# On a fresh machine, `noctalia msg templates-apply` writes it immediately.
#
# host.kdl is included LAST in config.kdl on purpose: niri merges includes
# positionally, so the host file overrides shared values (layout and input
# merge field by field, a bind with the same key replaces the shared one,
# outputs and window rules accumulate). Verified against niri-config's
# ConfigPart::decode_children (niri 26.04).
#
# niri resolves `include` relative to the directory of the config file it was
# handed (~/.config/niri), NOT the symlink's target — verified directly, which
# is what makes this split work while config.kdl lives in the repo.
#
# A MISSING non-optional include is a fatal parse error: niri rejects the
# entire config and the session will not start. Any host importing the niri
# feature must have dotfiles/niri/hosts/<hostname>/host.kdl.
{
  flake.modules.homeManager.niri =
    {
      config,
      osConfig,
      ...
    }:
    let
      src = "${config.dotfiles.repoPath}/dotfiles/niri";

      # `osConfig` is the enclosing NixOS configuration — available because
      # home-manager runs as a NixOS module here.
      hostDir = "${src}/hosts/${osConfig.networking.hostName}";

      link = target: { source = config.lib.file.mkOutOfStoreSymlink target; };
    in
    {
      xdg.configFile = {
        "niri/config.kdl" = link "${src}/.config/niri/config.kdl";
        "niri/host.kdl" = link "${hostDir}/host.kdl";
      };
    };
}
