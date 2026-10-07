# Discord via Vesktop: a Vencord-based client whose screen sharing works
# through the xdg portal on niri (audio included), unlike the official app.
#
# Hybrid management: only the app-level settings below are pinned. HM writes
# them as a read-only ~/.config/vesktop/settings.json, so toggling these in the
# GUI won't stick -- change them here. Vencord's own settings (plugins,
# enabled themes, QuickCSS) live in vesktop/settings/settings.json, which is
# left unmanaged so the GUI owns it.
{
  flake.modules.homeManager.shashin =
    { ... }:
    {
      programs.vesktop = {
        enable = true;
        settings = {
          checkUpdates = false; # updates come from nixpkgs
          discordBranch = "stable";
          hardwareAcceleration = true;
          arRPC = false; # rich presence bridge for games; off by default
          tray = true;
          minimizeToTray = true;
        };
      };
    };
}
