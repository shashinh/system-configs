# The user account shared by every host. Hosts append host-specific
# extraGroups (nostromo: i2c; serenity: lact-gpu-monitoring) in their own
# modules — list options merge across definitions.
{
  flake.modules.nixos.shashin =
    { pkgs, ... }:
    {
      users.users.shashin = {
        isNormalUser = true;
        description = "Shashin Halalingaiah";
        extraGroups = [
          "wheel" # sudo access
          "networkmanager" # manage WiFi/Ethernet without sudo
          "video" # GPU/display access
          "audio" # audio devices
          "input" # input devices (needed by some Wayland compositors)
          "tss" # TPM access (tpm2-tools)
        ];
        # Shell defaults to bash. Change to pkgs.fish or pkgs.zsh here if you prefer.
        shell = pkgs.bash;
      };
    };
}
