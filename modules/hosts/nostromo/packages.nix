# Host-specific packages and containers.
# (nwg-look, adw-gtk3, papirus-icon-theme, udiskie, okular and ddcutil moved
# to modules/features/noctalia/desktop-packages.nix on 2026-10-01: they belong
# to the niri + Noctalia desktop, not to this hardware.)
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
        pcsx2
        ppsspp
      ];

      # Rootless Podman (no persistent root daemon, unlike Docker).
      virtualisation.podman.enable = true;
    };
}
