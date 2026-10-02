# serenity's host-side overrides of the shared home-manager config
# (modules/users/shashin/home/*.nix, imported via home-shashin). Everything
# not listed here is exactly nostromo's user experience.
{
  flake.modules.nixos.serenity =
    { lib, ... }:
    {
      home-manager.users.shashin = {
        # 96 dpi for GTK font sizing on the 34" 3440x1440 panel at scale 1
        # (what KDE had set here); nostromo's shared value of 120 dpi is a
        # laptop choice. 1024 * 96.
        gtk.gtk3.extraConfig.gtk-xft-dpi = lib.mkForce 98304;
        gtk.gtk4.extraConfig.gtk-xft-dpi = lib.mkForce 98304;

        # The shared obsidian.toml points at nostromo's vault; serenity's
        # template lives in dotfiles/noctalia/hosts/serenity/host.toml.
        xdg.configFile."noctalia/obsidian.toml".enable = lib.mkForce false;
      };
    };
}
