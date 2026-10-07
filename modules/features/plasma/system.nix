# KDE Plasma 6 with the Plasma login manager.
#
# Dormant since 2026-10-01: serenity moved to niri + Noctalia. Kept as the
# emergency revert, together with dotfiles.nix (seeds the backed-up KDE user
# config from dotfiles/kde/) and dotfiles/kde/README.md (the revert recipe).
# Mutually exclusive with the greetd feature (both claim the display
# manager); a host imports one or the other.
{
  flake.modules.nixos.plasma =
    { pkgs, ... }:
    {
      services.displayManager.plasma-login-manager = {
        enable = true;
        package = pkgs.kdePackages.plasma-login-manager;
      };

      services.desktopManager.plasma6.enable = true;

      # KDE-only extras, moved out of the pc baseline on 2026-10-01: a KWin
      # effect, Plasma's browser bridge, the Plasma vault UI and KDE-flavoured
      # apps that only make sense inside a Plasma session. kcalc, kdenlive
      # and kdeconnect stay in pc; they work under any desktop.
      environment.systemPackages = with pkgs; [
        kde-rounded-corners
        whitesur-cursors # the cursor theme kdedefaults/kcminputrc names
        kdePackages.plasma-browser-integration
        kdePackages.plasma-vault
        kdePackages.koko
        kdePackages.keditbookmarks
      ];
      programs.firefox.nativeMessagingHosts.packages = [ pkgs.kdePackages.plasma-browser-integration ];
    };
}
