# AMD graphics/firmware baseline (both hosts are AMD).
{
  flake.modules.nixos.pc =
    { config, lib, ... }:
    {
      hardware = {
        # Loads non-free firmware blobs (WiFi, Bluetooth, AMD GPU microcode).
        enableRedistributableFirmware = true;

        # The nixos-hardware module enables most of this; these are belt-and-
        # suspenders settings.
        amdgpu = {
          opencl.enable = true; # OpenCL compute (needed for some apps)
          # flake check warned below is not needed
          # amdvlk.enable   = false;  # use Mesa RADV (better for games/Wayland)
        };

        # Mesa OpenGL/Vulkan + 32-bit compatibility (Steam, Wine).
        graphics = {
          enable = true;
          enable32Bit = true;
        };

        # CPU microcode updates (applied at boot, before userspace starts).
        cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      };
    };
}
