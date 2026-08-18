{ config, lib, pkgs, inputs, ... }:

{
  programs.niri.enable = true;

  # niri doesn't bundle Xwayland itself; X11-only apps (e.g. Zoom) need this
  # running to get a DISPLAY. Spawned at startup from niri's config.kdl.
  environment.systemPackages = [ pkgs.xwayland-satellite ];

  # niri.nix and plasma6.nix both use mkDefault to pin their own session as
  # the default, which conflicts since neither wins at equal priority.
  # This just sets which one is pre-selected at the greeter — both Plasma
  # and Niri sessions remain selectable either way, since each module
  # registers its own session package independently.
  services.displayManager.defaultSession = lib.mkForce "niri";
}
