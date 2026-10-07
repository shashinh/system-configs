{
  flake.modules.nixos.pc = {
    security.polkit.enable = true;

    # Allow users in the `wheel` group to use sudo.
    security.sudo.wheelNeedsPassword = true;
  };
}
