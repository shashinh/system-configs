{ config, lib, pkgs, inputs, ... }:

{
  programs.niri.enable = true;

  # niri doesn't bundle Xwayland itself; X11-only apps (e.g. Zoom) need this
  # running to get a DISPLAY. Spawned at startup from niri's config.kdl.
  environment.systemPackages = [ pkgs.xwayland-satellite ];

  # niri.nix and plasma6.nix both use mkDefault to pin their own session as
  # the default, which conflicts since neither wins at equal priority.
  # NOTE: since switching to greetd/tuigreet (configuration.nix), tuigreet
  # doesn't read this option — it just remembers whichever session you last
  # picked (--remember-session). This is left set as a harmless default for
  # any other display-manager tooling that does honor it; both Plasma and
  # Niri sessions remain selectable at the tuigreet menu either way.
  services.displayManager.defaultSession = lib.mkForce "niri";
}
