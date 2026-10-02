# Baseline programs shared by every PC.
{
  flake.modules.nixos.pc = {
    programs = {
      # Git global config (minimal — user-level config belongs in Home Manager).
      git.enable = true;

      # dconf is required by GNOME/GTK apps and some KDE settings.
      dconf.enable = true;

      # The plasma-browser-integration native host moved to the plasma
      # feature on 2026-10-01 (KDE-only).
      firefox.enable = true;

      kdeconnect.enable = true;
    };
  };
}
