# Baseline programs shared by every PC.
{
  flake.modules.nixos.pc =
    { pkgs, ... }:
    {
      programs = {
        # Git global config (minimal — user-level config belongs in Home Manager).
        git.enable = true;

        # dconf is required by GNOME/GTK apps and some KDE settings.
        dconf.enable = true;

        firefox = {
          enable = true;
          nativeMessagingHosts.packages = [ pkgs.kdePackages.plasma-browser-integration ];
        };

        kdeconnect.enable = true;
      };
    };
}
