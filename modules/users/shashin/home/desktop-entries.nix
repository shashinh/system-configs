{
  flake.modules.homeManager.shashin =
    { ... }:

# Custom launcher entries for app-launch variants that don't get their own
# .desktop file upstream (e.g. "always open a private window", "always
# start a fresh instance"). Noctalia's launcher reads standard XDG desktop
# entries from the usual search paths (including this profile's
# share/applications), deduplicated by app-id + exec command, so a new
# Exec= here is enough to show up as its own distinct launcher entry
# alongside the regular Firefox/VLC ones — no Noctalia-specific wiring
# needed. Noctalia may need a restart to pick up a newly-added entry.
{
  xdg.desktopEntries = {
    # not needed with the Noctalia V5 application launcher
    # firefox-private = {
    #   name = "Firefox (Private Window)";
    #   genericName = "Private Web Browser";
    #   exec = "firefox --private-window %U";
    #   icon = "firefox";
    #   categories = [ "Network" "WebBrowser" ];
    #   terminal = false;
    # };

    # still needed, VLC does not have a new instance option out the box
    vlc-new-instance = {
      name = "VLC (New Instance)";
      genericName = "Media Player";
      # --no-one-instance overrides VLC's default single-instance behavior
      # (reusing an already-running VLC and just queuing the file), forcing
      # a genuinely separate process every time this entry is launched.
      exec = "vlc --no-one-instance %U";
      icon = "vlc";
      categories = [ "AudioVideo" "Player" ];
      terminal = false;
    };

    # Overrides Loupe's own packaged .desktop entry (attribute name here
    # must match its filename exactly — home-manager marks entries defined
    # here hiPrio so they win the profile-merge collision). Loupe ships
    # DBusActivatable=true, which per the desktop-entry spec tells a
    # compliant launcher to ignore Exec= entirely and activate over D-Bus
    # instead (see https://wiki.gnome.org/HowDoI/DBusApplicationLaunching).
    # Noctalia's launcher does that half but drops the file argument along
    # the way, so "open with" just opened a blank Loupe window — confirmed
    # by testing `loupe <file>` directly (works) vs. through the launcher
    # (doesn't). Dropping DBusActivatable forces Exec=loupe %U instead,
    # which every launcher handles correctly. Same category of bug as
    # https://github.com/void-linux/void-packages/issues/48242 (Nautilus).
    "org.gnome.Loupe" = {
      name = "Image Viewer";
      comment = "View and edit images";
      exec = "loupe %U";
      icon = "org.gnome.Loupe";
      terminal = false;
      categories = [ "GNOME" "GTK" "Graphics" "2DGraphics" "RasterGraphics" "Viewer" ];
      mimeType = [
        "image/apng" "image/bmp" "image/gif" "image/jp2" "image/jpeg"
        "image/png" "image/qoi" "image/tiff" "image/vnd.microsoft.icon"
        "image/webp" "image/x-dds" "image/x-exr" "image/x-portable-anymap"
        "image/x-portable-bitmap" "image/x-portable-graymap"
        "image/x-portable-pixmap" "image/x-qoi" "image/x-tga"
        "image/x-win-bitmap" "image/x-xbitmap" "image/x-xpixmap"
        "image/svg+xml" "image/svg+xml-compressed" "image/avif"
        "image/heic" "image/jxl"
      ];
      settings.DBusActivatable = "false";
    };

    brain-fm = {
      name = "Brain.fm";
      genericName = "Focus Music";
      exec = "firefox --new-window https://my.brain.fm";
      icon = "firefox";
      categories = [ "Network" "Audio" ];
      terminal = false;
    };
  };
}
;
}
