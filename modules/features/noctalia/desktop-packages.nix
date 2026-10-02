# Desktop support packages for the niri + Noctalia session, and the i2c
# access Noctalia's ddcutil brightness backend needs on external monitors.
# Shared by every host that imports the noctalia feature; a host adds to
# environment.systemPackages in its own files, or removes with lib.mkForce.
#
# Moved here from modules/hosts/nostromo/{packages,hardware}.nix on
# 2026-10-01 when serenity joined; content unchanged.
{
  flake.modules.nixos.noctalia =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        ddcutil # external-monitor brightness (Noctalia: brightness.enable_ddcutil)
        nwg-look # GTK theme picker (dconf side only; HM owns settings.ini)
        adw-gtk3 # GTK3 theme that consumes Noctalia's generated colours
        papirus-icon-theme
        udiskie # removable-media automounter/tray
        kdePackages.okular # PDF viewer (default-apps.nix: application/pdf)
      ];

      # ddcutil talks DDC/CI over the GPU's i2c buses.
      hardware.i2c.enable = true;
      users.users.shashin.extraGroups = [ "i2c" ];
    };
}
