# Hardware scan results (originally nixos-generate-config output) plus
# host-specific kernel parameters.
{
  flake.modules.nixos.serenity =
    { config, lib, modulesPath, ... }:
    {
      imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

      boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "thunderbolt" "usbhid" "usb_storage" "sd_mod" ];
      boot.initrd.kernelModules = [ ];
      boot.kernelModules = [ "kvm-amd" ];
      boot.extraModulePackages = [ ];

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

      # from
      #   https://www.jeffgeerling.com/blog/2025/increasing-vram-allocation-on-amd-ai-apus-under-linux/
      #   https://community.frame.work/t/updated-commands-to-increase-max-unified-memory-usage-on-framework-desktop-under-fedora-43/78460
      #   to check, after reboot:
      # sudo dmesg | grep "amdgpu.*memory"
      boot.kernelParams = [
        "ttm.pages_limit=27648000"
        "ttm.page_pool_size=27648000"
      ];
    };
}
