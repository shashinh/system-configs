# serenity's host-side overrides of the shared home-manager config
# (modules/users/shashin/home/*.nix, imported via home-shashin). Everything
# not listed here is exactly nostromo's user experience.
{
  flake.modules.nixos.serenity =
    { lib, ... }:
    {
      home-manager.users.shashin = {
        # 10pt UI font on the 34" 3440x1440 panel at scale 1 (what KDE had
        # set here); the shared 11pt is a laptop choice. Qt follows it.
        gtk.font.size = lib.mkForce 10;

        # The shared obsidian.toml points at nostromo's vault; serenity's
        # template lives in dotfiles/noctalia/hosts/serenity/host.toml.
        xdg.configFile."noctalia/obsidian.toml".enable = lib.mkForce false;
      };
    };
}
