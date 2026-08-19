{ ... }:

# Ports the mime associations KDE had set up imperatively in
# ~/.config/mimeapps.list into home-manager, plus Thunar as the default file
# manager (inode/directory). Dolphin stays installed via plasma6.
let
  associations = {
    "application/x-extension-htm" = "firefox.desktop";
    "application/x-extension-html" = "firefox.desktop";
    "application/x-extension-shtml" = "firefox.desktop";
    "application/x-extension-xht" = "firefox.desktop";
    "application/x-extension-xhtml" = "firefox.desktop";
    "application/xhtml+xml" = "firefox.desktop";
    "text/html" = "firefox.desktop";
    "x-scheme-handler/chrome" = "firefox.desktop";
    "x-scheme-handler/http" = "firefox.desktop";
    "x-scheme-handler/https" = "firefox.desktop";

    "application/x-matroska" = "vlc.desktop";
    "video/3gp" = "vlc.desktop";
    "video/3gpp" = "vlc.desktop";
    "video/3gpp2" = "vlc.desktop";
    "video/avi" = "vlc.desktop";
    "video/divx" = "vlc.desktop";
    "video/dv" = "vlc.desktop";
    "video/fli" = "vlc.desktop";
    "video/flv" = "vlc.desktop";
    "video/mp2t" = "vlc.desktop";
    "video/mp4" = "vlc.desktop";
    "video/mp4v-es" = "vlc.desktop";
    "video/mpeg" = "vlc.desktop";
    "video/msvideo" = "vlc.desktop";
    "video/ogg" = "vlc.desktop";
    "video/quicktime" = "vlc.desktop";
    "video/vnd.divx" = "vlc.desktop";
    "video/vnd.mpegurl" = "vlc.desktop";
    "video/vnd.rn-realvideo" = "vlc.desktop";
    "video/webm" = "vlc.desktop";
    "video/x-avi" = "vlc.desktop";
    "video/x-flv" = "vlc.desktop";
    "video/x-m4v" = "vlc.desktop";
    "video/x-matroska" = "vlc.desktop";
    "video/x-mpeg2" = "vlc.desktop";
    "video/x-ms-asf" = "vlc.desktop";
    "video/x-ms-wmv" = "vlc.desktop";
    "video/x-ms-wmx" = "vlc.desktop";
    "video/x-msvideo" = "vlc.desktop";
    "video/x-ogm" = "vlc.desktop";
    "video/x-ogm+ogg" = "vlc.desktop";
    "video/x-theora" = "vlc.desktop";
    "video/x-theora+ogg" = "vlc.desktop";

    "image/avif" = "org.kde.koko.desktop";
    "image/bmp" = "org.kde.koko.desktop";
    "image/heif" = "org.kde.koko.desktop";
    "image/jpeg" = "org.kde.koko.desktop";
    "image/png" = "org.kde.koko.desktop";
    "image/webp" = "org.kde.koko.desktop";

    "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
    "x-scheme-handler/geo" = "google-maps-geo-handler.desktop";
    "x-scheme-handler/obsidian" = "obsidian.desktop";
    "x-scheme-handler/slack" = "slack.desktop";
  };
in
{
  xdg.mimeApps = {
    enable = true;
    associations.added = associations;
    defaultApplications = associations // {
      "inode/directory" = "thunar.desktop";
    };
  };
}
