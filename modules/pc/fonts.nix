# Fonts installed on every PC.
#
# Shared because the fontconfig defaults (modules/pc/fontconfig.nix) name
# "JetBrainsMono Nerd Font", "Noto Sans/Serif" and "Noto Color Emoji" on both
# hosts. noto-fonts/-color-emoji and the nerd fonts used to arrive
# transitively via services.desktopManager.plasma6.enable (its module adds
# fonts.packages = [ cfg.notoPackage pkgs.hack-font ]); with Plasma gone from
# both hosts they are installed explicitly here.
#
# Per-host override: fonts.packages is a list, so a host ADDS fonts by
# declaring more in modules/hosts/<host>/; to drop one of these, a host
# sets fonts.packages = lib.mkForce [ ... ] (see the skill, "Configure a
# feature differently per host").
{
  flake.modules.nixos.pc =
    { pkgs, ... }:
    {
      fonts.packages = with pkgs; [
        font-awesome
        nerd-fonts.fira-code
        nerd-fonts.droid-sans-mono
        nerd-fonts.jetbrains-mono
        noto-fonts
        noto-fonts-color-emoji
      ];
    };
}
