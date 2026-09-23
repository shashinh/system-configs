# KDE Plasma 6 with the Plasma login manager.
{
  flake.modules.nixos.serenity =
    { pkgs, ... }:
    {
      services.displayManager.plasma-login-manager = {
        enable = true;
        package = pkgs.kdePackages.plasma-login-manager;
      };

      services.desktopManager.plasma6.enable = true;

      services.fprintd.enable = false;

      # Wire fingerprint into PAM so you can use it instead of a password for
      # sudo and login. SDDM fingerprint support is limited on Wayland;
      # see INSTALL.md notes on enrolling prints after first boot.
      #   security.pam.services = {
      #     login.fprintAuth = true;
      #     sudo.fprintAuth  = true;
      #     # Uncomment once you have confirmed fprintd detects your reader:
      #     # polkit-1.fprintAuth = true;
      #   };
    };
}
