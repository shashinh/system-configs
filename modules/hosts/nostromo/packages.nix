# Host-specific packages and containers.
{
  flake.modules.nixos.nostromo =
    { pkgs, ... }:
    {
      # Only system-wide tools go here. Per-user packages belong in Home
      # Manager or in users.users.shashin.packages.
      environment.systemPackages = with pkgs; [
        # Wayland utilities
        wl-clipboard # wl-copy / wl-paste
        xdg-utils # xdg-open etc.
        evtest

        ddcutil
        nwg-look
        adw-gtk3
        papirus-icon-theme
        udiskie

        kdePackages.okular
      ];

      # Rootless Podman (no persistent root daemon, unlike Docker).
      virtualisation.podman.enable = true;
    };
}
