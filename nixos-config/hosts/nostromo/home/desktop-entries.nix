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
    firefox-private = {
      name = "Firefox (Private Window)";
      genericName = "Private Web Browser";
      exec = "firefox --private-window %U";
      icon = "firefox";
      categories = [ "Network" "WebBrowser" ];
      terminal = false;
    };

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
  };
}
