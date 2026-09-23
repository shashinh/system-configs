{ ... }:

{
  programs.kitty = {
    enable = true;

    font = {
      name = "FiraCode Nerd Font";
      size = 10;
    };

    settings = {
      scrollback_lines = 10000;
      confirm_os_window_close = 0;
    };

    # Noctalia writes its live theme here and expects kitty.conf to include
    # it; see theme.templates.builtin_ids in noctalia's settings.toml.
    extraConfig = ''
      include themes/noctalia.conf
    '';
  };
}
