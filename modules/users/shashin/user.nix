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
        # Login shell. Its config is home-manager's (home/zsh.nix); bash
        # stays configured (home/bash.nix) as a fallback.
        shell = pkgs.zsh;
      };

      # Required for a zsh login shell (/etc/zshenv, /etc/shells entry).
      # home-manager runs compinit itself; the global one would be a second,
      # slower pass. pathsToLink exposes packages' share/zsh completions.
      programs.zsh = {
        enable = true;
        enableGlobalCompInit = false;
      };
      environment.pathsToLink = [ "/share/zsh" ];
    };
}
