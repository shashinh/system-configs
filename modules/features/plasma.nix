# KDE Plasma 6 with the Plasma login manager.
# Mutually exclusive with the greetd feature (both claim the display
# manager); a host imports one or the other.
{
  flake.modules.nixos.plasma =
    { pkgs, ... }:
    {
      services.displayManager.plasma-login-manager = {
        enable = true;
        package = pkgs.kdePackages.plasma-login-manager;
      };

      services.desktopManager.plasma6.enable = true;
    };
}
