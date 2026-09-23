# Hardware scan results (originally nixos-generate-config output) plus
# host-specific hardware toggles and zram tuning.
{
  flake.modules.nixos.nostromo =
    { config, lib, modulesPath, ... }:
    {
      imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

      boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "thunderbolt" "usbhid" "usb_storage" "sd_mod" ];
      boot.initrd.kernelModules = [ ];
      boot.kernelModules = [ "kvm-amd" ];
      boot.extraModulePackages = [ ];

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

      # i2c for external monitor control (ddcutil).
      hardware.i2c.enable = true;
      users.users.shashin.extraGroups = [ "i2c" ];

      #QMK support
      hardware.keyboard.qmk.enable = true;

      # zram is RAM-backed and fast, so the kernel should reach for it much more
      # eagerly than it would for disk-backed swap (default swappiness = 60).
      boot.kernel.sysctl."vm.swappiness" = 150;
    };
}
