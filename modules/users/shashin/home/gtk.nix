{
  flake.modules.homeManager.shashin =
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
# Icon/cursor theme: previously breeze-dark/breeze_cursors, installed
# system-wide as a side effect of KDE Plasma. Now that KDE is removed,
# explicitly pull in Adwaita (icons + cursors both ship in the one
# adwaita-icon-theme package) instead.
#
# The actual system pointer (what niri/Wayland clients like Firefox draw
# for the mouse cursor, as opposed to widget-internal GTK rendering) reads
# XCURSOR_THEME from the session environment, not gtk-3.0/settings.ini.
# With nothing setting that var it fell back to GDK's own hardcoded
# "default" theme name — the classic ugly X cursor. home.pointerCursor
# (below) sets XCURSOR_THEME/SIZE via home.sessionVariables (session-wide,
# inherited by every spawned app) and, via gtk.enable, also supplies
# gtk.cursorTheme itself — so the manual cursorTheme block was dropped
# here to avoid a redundant second source of truth.
{
  home.pointerCursor = {
    enable = true;
    package = pkgs.adwaita-icon-theme;
    name = "Adwaita";
    size = 24;
    gtk.enable = true;
  };

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

    # Papirus-Dark, matching what nwg-look was being used to set. Declared
    # here because home-manager owns BOTH sinks GTK reads — it writes
    # ~/.config/gtk-{3,4}.0/settings.ini (as read-only store symlinks) and
    # dconf org/gnome/desktop/interface. nwg-look can only write the latter,
    # so its choice survived until the next activation and was then reverted.
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };

    # Noctalia writes its palette to ~/.config/gtk-{3,4}.0/noctalia.css, and
    # its apply.sh ensures gtk.css imports it. That script returns early —
    # leaving gtk.css untouched — as soon as the file already contains the
    # import, so home-manager can own gtk.css outright provided we keep that
    # line. (Without it, apply.sh deletes the read-only store symlink.)
    #
    # The override exists because adw-gtk3 and libadwaita paint a SELECTED
    # row's text with window_fg_color (near-white) and its background from the
    # accent. That assumes a DARK accent — true of their default blue, false
    # for Noctalia, whose accent is wallpaper-derived and currently a light
    # amber (#f1bf48). Near-white on light amber is unreadable.
    #
    # Measured on this machine: a selected row resolves fg=#e2e2e2 in BOTH
    # GTK3 and GTK4, while Noctalia generates a properly contrasting
    # accent_fg_color (#3f2e00) that neither theme consults for list
    # selections. So pin the pair Noctalia generated for exactly this purpose.
    gtk3.extraCss = ''
      @import url("noctalia.css");

      treeview.view:selected, treeview.view:selected:focus,
      .view:selected, iconview:selected,
      list > row:selected, row:selected {
        background-color: @accent_bg_color;
        color: @accent_fg_color;
      }
    '';

    gtk4.extraCss = ''
      @import url("noctalia.css");

      listview > row:selected, list > row:selected, row:selected,
      gridview > child:selected, columnview > row:selected {
        background-color: @accent_bg_color;
        color: @accent_fg_color;
      }
    '';

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
;
}
