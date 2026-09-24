# The niri scrolling compositor.
{ inputs, ... }:
{
  flake.modules.nixos.niri =
    { lib, pkgs, ... }:
    {
      programs.niri.enable = true;

      # niri doesn't bundle Xwayland itself; X11-only apps (e.g. Zoom) need
      # this running to get a DISPLAY. Spawned at startup from config.kdl.
      environment.systemPackages = [ pkgs.xwayland-satellite ];

      # mkForce guards against another module setting its own mkDefault
      # session (desktop-manager modules commonly do). NOTE: with the greetd
      # feature, tuigreet doesn't read this option — it remembers whichever
      # session you last picked (--remember-session). Left set as a harmless
      # default for any other display-manager tooling that does honor it.
      services.displayManager.defaultSession = lib.mkForce "niri";

      # Deliver the home-manager half of this feature (dotfiles.nix) to every
      # HM user on the host. Single wiring point for the user-side config —
      # keep it here, in the feature's primary file.
      #
      # Requires the host to enable home-manager (import `home-shashin`).
      home-manager.sharedModules = [ inputs.self.modules.homeManager.niri ];
    };
}
