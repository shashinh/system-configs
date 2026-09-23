# nostromo's installed fonts.
# noto-fonts/-color-emoji and nerd-fonts.jetbrains-mono used to arrive
# transitively via services.desktopManager.plasma6.enable (its module
# adds fonts.packages = [ cfg.notoPackage pkgs.hack-font ]), so the
# fontconfig defaultFonts silently resolved even though nothing
# here installed them explicitly. Removing KDE dropped that and every
# default fell back to DejaVu — now installed explicitly instead.
{
  flake.modules.nixos.nostromo =
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
