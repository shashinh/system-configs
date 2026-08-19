{ pkgs, ... }:

# GTK widget theme, split out from KDE's own GTK sync (see below).
#
# Why this file exists: Noctalia's GTK3/GTK4 color templates (enabled via
# Settings -> Templates -> Built-in -> GTK 3 / GTK 4) write standard
# libadwaita-style color variables (theme_selected_bg_color, accent_color,
# etc.) into ~/.config/gtk-{3,4}.0/noctalia.css. KDE's Breeze theme — which
# was set here imperatively by Plasma's own "GTK sync" the first time this
# machine ran Plasma, and was never managed by nix — doesn't read those
# variable names at all. Its own stylesheet defines a separately-namespaced
# set instead (theme_selected_bg_color_breeze and friends), hardcoded at
# whatever accent color Plasma's color scheme last pushed into
# ~/.config/gtk-3.0/colors.css (a dark red, #8a2628, in this case). That
# mismatch is why Firefox's text-selection highlight (and in principle any
# other GTK-native widget color) stayed red no matter what Noctalia
# generated — Breeze was structurally incapable of consuming it.
#
# Fix: adw-gtk3 is a GTK3 theme purpose-built to mirror libadwaita and
# consume exactly the variable names Noctalia writes, so the generated
# palette actually takes effect. GTK4 apps render with libadwaita's own
# built-in style already, so no separate GTK4 theme package is needed.
#
# Icon/cursor theme are left as breeze-dark/breeze_cursors (from Plasma 6,
# installed system-wide via services.desktopManager.plasma6.enable in
# configuration.nix) — only the widget theme needed to change.
{
  gtk = {
    enable = true;
    colorScheme = "dark";

    font = {
      name = "Noto Sans";
      size = 10;
    };

    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };

    iconTheme.name = "breeze-dark";

    cursorTheme = {
      name = "breeze_cursors";
      size = 24;
    };

    gtk3.extraConfig = {
      gtk-decoration-layout = "icon:minimize,maximize,close";
      gtk-primary-button-warps-slider = true;
      gtk-sound-theme-name = "ocean";
      gtk-xft-dpi = 122880;
      gtk-toolbar-style = 3;
      gtk-button-images = true;
      gtk-menu-images = true;
      gtk-cursor-blink = true;
      gtk-cursor-blink-time = 1000;
      # gtk-modules (colorreload-gtk-module, window-decorations-gtk-module)
      # deliberately dropped: both are Breeze-specific plugins with nothing
      # to do now that Breeze isn't the active theme.
    };

    gtk4.extraConfig = {
      gtk-decoration-layout = "icon:minimize,maximize,close";
      gtk-primary-button-warps-slider = true;
      gtk-sound-theme-name = "ocean";
      gtk-xft-dpi = 122880;
      gtk-cursor-blink = true;
      gtk-cursor-blink-time = 1000;
    };
  };
}
