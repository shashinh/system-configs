{
  flake.modules.nixos.niri =
    { lib, pkgs, ... }:

{
  programs.niri.enable = true;

  # niri doesn't bundle Xwayland itself; X11-only apps (e.g. Zoom) need this
  # running to get a DISPLAY. Spawned at startup from niri's config.kdl.
  environment.systemPackages = [ pkgs.xwayland-satellite ];

  # mkForce here guards against any other module setting its own mkDefault
  # session (desktop-manager modules commonly do). NOTE: since switching to
  # greetd/tuigreet (configuration.nix), tuigreet doesn't read this option —
  # it just remembers whichever session you last picked (--remember-session).
  # Left set as a harmless default for any other display-manager tooling that
  # does honor it.
  services.displayManager.defaultSession = lib.mkForce "niri";
}
;
}
