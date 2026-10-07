# Host-specific packages that aren't part of a larger feature here.
{
  flake.modules.nixos.serenity =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        # Wayland utilities
        wl-clipboard # wl-copy / wl-paste
        xdg-utils # xdg-open etc.

        claude-code
      ];
    };
}
