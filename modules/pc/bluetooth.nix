{
  flake.modules.nixos.pc = {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          ControllerMode = "dual";
          JustWorksRepairing = "confirm";
        };
      };
    };
  };
}
