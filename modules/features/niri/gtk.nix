# GTK tweaks that only make sense under niri; delivered with the niri
# feature (its homeManager half), so a host without niri keeps the defaults.
{
  flake.modules.homeManager.niri = {
    # No minimize/maximize/close on client-side titlebars (":" = nothing on
    # either side): niri tiles, and closes with Mod+Q. Mainly for Firefox
    # with its "Title bar" option off, which draws its own titlebar despite
    # prefer-no-csd and takes its buttons from this GTK setting. Overrides
    # the mkDefault in modules/users/shashin/home/gtk.nix, in all three
    # places GTK reads it from.
    gtk.gtk3.extraConfig.gtk-decoration-layout = ":";
    gtk.gtk4.extraConfig.gtk-decoration-layout = ":";
    dconf.settings."org/gnome/desktop/wm/preferences".button-layout = ":";
  };
}
