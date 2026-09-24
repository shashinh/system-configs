# Thunar file manager.
#
# Thunar loads plugins ONLY from its own lib/thunarx-3 directory, which is
# fixed at build time. A plugin installed as a separate package lands in a
# different store path that Thunar never reads, so it silently does nothing.
# The NixOS module is the only correct route — it rebuilds Thunar with the
# plugins baked in:
#
#     package = pkgs.thunar.override { thunarPlugins = cfg.plugins; };
#
# Consequently Thunar must NOT also be in home.packages: that unwrapped copy
# takes precedence in PATH and has no plugins.
#
# Enabling this also turns on programs.xfconf (Thunar stores its per-folder
# view settings there).
{
  flake.modules.nixos.thunar =
    { pkgs, ... }:
    {
      programs.thunar = {
        enable = true;
        plugins = with pkgs; [
          # "Extract Here" / "Create Archive" context-menu entries. Shells out
          # to an archive manager found on PATH (xarchiver, installed as a user
          # package) rather than doing the work itself.
          thunar-archive-plugin
        ];
      };
    };
}
