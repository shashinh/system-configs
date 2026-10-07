{
  flake.modules.homeManager.shashin =
    { config, ... }:

    # Qt widget theme via qt6ct, so Qt/KDE apps (Okular, etc.) follow Noctalia.
    #
    # Noctalia's "Qt" template (Settings -> Templates) only WRITES a palette
    # to ~/.config/qt{5,6}ct/colors/noctalia.conf; nothing reads it unless a
    # qtct platform theme is loaded and its config points at that file.
    # Without this module Qt apps fell back to their built-in white palette.
    #
    # platformTheme "qtct" installs qt5ct + qt6ct and sets
    # QT_QPA_PLATFORMTHEME=qt5ct. qt6ct's plugin registers under both keys
    # ("qt6ct", "qt5ct"), so the one variable covers Qt5 and Qt6 apps.
    #
    # qt6ct here is plain upstream 0.11 (kdePackages.qt6ct is the identical
    # derivation, not the AUR "qt6ct-kde" fork), so it can't read Noctalia's
    # KColorScheme output — the qt template's palette is what's used. Zero
    # KDE packages in its closure.
    #
    # KDE apps also run KColorSchemeManager, which overrides the qt6ct
    # palette whenever the platform theme isn't "kde": it applies
    # [UiSettings] ColorScheme from kdeglobals, and with that unset falls
    # back to Breeze Light/Dark by the style hints — Breeze Light (stark
    # white) here, since plain qt6ct reports no dark preference. (Bridging
    # that is what the qt6ct-kde patch does.) So point it at the KColorScheme
    # Noctalia's "kcolorscheme" template writes to
    # ~/.local/share/color-schemes/noctalia.colors. Noctalia itself writes
    # kdeglobals, so set just this key in place (kwriteconfig6 at
    # activation) rather than taking over the file.
    #
    # Fonts follow gtk.nix. GTK scales its point size by gtk-xft-dpi (120 dpi
    # shared, 96 on serenity via modules/hosts/serenity/home.nix), while Qt
    # on Wayland always renders points at 96 dpi; so the Qt size is the GTK
    # size rescaled to 96 dpi, and a host's GTK dpi override carries over.
    # The qt*ct GUIs can't save over these files (read-only store links):
    # change fonts here.
    let
      palette = qtct: "${config.xdg.configHome}/${qtct}/colors/noctalia.conf";
      gtkDpi = config.gtk.gtk3.extraConfig.gtk-xft-dpi / 1024.0;
      size = toString (config.gtk.font.size * gtkDpi / 96);
      # Qt5's 10-field QFont::toString() form (weight 50 = normal), which Qt5
      # writes natively and Qt 6.11 still parses (mapping 50 -> 400); Qt 6
      # rejects shorter strings outright. Quoted, or QSettings splits the
      # commas into a list and qt*ct reads no font.
      font = family: ''"${family},${size},-1,5,50,0,0,0,0,0"'';
      settings = qtct: {
        Appearance = {
          style = "Fusion";
          custom_palette = true;
          color_scheme_path = palette qtct;
          icon_theme = config.gtk.iconTheme.name; # match GTK (gtk.nix)
          standard_dialogs = "xdgdesktopportal"; # same file chooser as GTK apps
        };
        Fonts = {
          general = font config.gtk.font.name;
          fixed = font "monospace"; # fontconfig's default monospace
        };
        Interface = {
          buttonbox_layout = 3; # GNOME button order, as in GTK dialogs
        };
      };
    in
    {
      qt = {
        enable = true;
        platformTheme.name = "qtct";
        qt5ctSettings = settings "qt5ct";
        qt6ctSettings = settings "qt6ct";
        kde.settings.kdeglobals.UiSettings.ColorScheme = "noctalia";
      };
    };
}
