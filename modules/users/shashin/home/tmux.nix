{
  flake.modules.homeManager.shashin =
    { ... }:

{
  programs.tmux = {
    enable = true;

    # prefix C-a: unbinds the default C-b, binds C-a, and wires
    # "C-a C-a" to send a literal C-a through to the running application,
    # equivalent to unbind/set -g prefix/bind trio.
    shortcut = "a";

    mouse = true;
    keyMode = "vi";
    historyLimit = 5000;

    # With keyMode "vi", also bind h/j/k/l to move focus between panes and
    # H/J/K/L (repeatable) to resize them in the same directions.
    customPaneNavigationAndResize = true;

    extraConfig = ''
      set -g default-command "''${SHELL}"

      # Forwards modified keys only to apps that request them. Keep this at
      # "on" rather than "always": snacks.nvim (see neovim.nix) only skips
      # its XTVERSION query for "on", and under "always" the terminal's reply
      # reaches nvim as typed keys and inserts text into the open buffer.
      set -g extended-keys on
      set -g allow-passthrough on
      # -a appends to tmux's built-in terminal-features table instead of
      # replacing it; without -a this line wipes out the compiled-in
      # xterm/screen/rxvt entries (clipboard, focus-events, cursor-style,
      # title-setting), breaking those features for every terminal.
      set -a terminal-features 'xterm*:extkeys'

      # ---- Status bar -------------------------------------------------
      # A powerline bar in the shape of the lualine statusline (neovim.nix):
      #   left   session block (recoloured for PREFIX/COPY/SYNC) > host
      #   middle window tabs
      #   right  pane directory, git branch < load, memory < clock, date
      # Plain tmux formats, no plugins. The glyphs are Nerd Font codepoints
      # written as \u escapes; kitty's font (kitty.nix) provides them.
      #
      # Colours are the @noctalia_* options that Noctalia's "tmux" community
      # template renders into ~/.config/tmux/themes/noctalia.conf (sourced on
      # the last line of this file). The formats read them at draw time, so
      # a re-sourced theme recolours the bar without reloading this config.
      # The values here are ANSI fallbacks for a machine where Noctalia has
      # not rendered the theme yet; the theme file overrides them.
      set -g @noctalia_surface_container_low black
      set -g @noctalia_surface_container brightblack
      set -g @noctalia_surface_container_high brightblack
      set -g @noctalia_on_surface white
      set -g @noctalia_on_surface_variant white
      set -g @noctalia_outline brightblack
      set -g @noctalia_primary brightgreen
      set -g @noctalia_on_primary black
      set -g @noctalia_secondary_container blue
      set -g @noctalia_on_secondary_container brightwhite
      set -g @noctalia_tertiary_container magenta
      set -g @noctalia_on_tertiary_container brightwhite
      set -g @noctalia_error_container red
      set -g @noctalia_on_error_container brightwhite
      set -g status-style "bg=black,fg=white"
      set -g window-status-current-style default

      set -g @sep_r ""      # filled arrow, pointing right
      set -g @sep_l ""      # filled arrow, pointing left
      set -g @sep_l_thin ""
      set -g @icon_branch ""
      set -g @icon_dir ""
      set -g @icon_load ""
      set -g @icon_mem ""
      set -g @icon_zoom ""
      set -g @icon_bell ""
      set -g @icon_activity ""
      set -g @icon_marked ""
      set -g @icon_last ""

      # Colours and label of the two end blocks, by client state. Expanded
      # with #{E:...} wherever they are used.
      set -g @mode_bg '#{?client_prefix,#{@noctalia_on_tertiary_container},#{?pane_in_mode,#{@noctalia_on_secondary_container},#{?pane_synchronized,#{@noctalia_error_container},#{@noctalia_primary}}}}'
      set -g @mode_fg '#{?client_prefix,#{@noctalia_tertiary_container},#{?pane_in_mode,#{@noctalia_secondary_container},#{?pane_synchronized,#{@noctalia_on_error_container},#{@noctalia_on_primary}}}}'
      set -g @mode_label '#{?client_prefix,PREFIX,#{?pane_in_mode,COPY,#{?pane_synchronized,SYNC,#S}}}'

      set -g status-interval 5
      set -g status-left-length 60
      set -g status-right-length 120

      set -g status-left '#[fg=#{E:@mode_fg},bg=#{E:@mode_bg},bold] #{E:@mode_label} #[fg=#{E:@mode_bg},bg=#{@noctalia_surface_container_high},nobold]#{@sep_r}#[fg=#{@noctalia_on_surface}] #h #[fg=#{@noctalia_surface_container_high},bg=#{@noctalia_surface_container_low}]#{@sep_r} '

      # Each tab is a block with an arrow cut into its left edge and an arrow
      # point on its right. The flag icons stand in for tmux's Z ! # M -
      # suffixes; the current window is marked by colour instead of "*".
      set -g @tab_flags '#{?window_zoomed_flag, #{@icon_zoom},}#{?window_bell_flag, #{@icon_bell},}#{?window_activity_flag, #{@icon_activity},}#{?window_marked_flag, #{@icon_marked},}#{?window_last_flag, #{@icon_last},}'
      set -g window-status-separator ""
      set -g window-status-format '#[fg=#{@noctalia_surface_container_low},bg=#{@noctalia_surface_container}]#{@sep_r}#[fg=#{@noctalia_on_surface_variant},nobold] #I #W#{E:@tab_flags} #[fg=#{@noctalia_surface_container},bg=#{@noctalia_surface_container_low}]#{@sep_r}'
      set -g window-status-current-format '#[fg=#{@noctalia_surface_container_low},bg=#{@noctalia_primary}]#{@sep_r}#[fg=#{@noctalia_on_primary},bold] #I #W#{E:@tab_flags} #[fg=#{@noctalia_primary},bg=#{@noctalia_surface_container_low},nobold]#{@sep_r}'

      # The branch lookup is the one shell call per refresh; load and memory
      # are read straight from /proc.
      set -g @git_branch '#(git -C "#{pane_current_path}" branch --show-current 2>/dev/null)'
      set -g status-right '#[fg=#{@noctalia_on_surface_variant}]#{@icon_dir} #{=/-32/…;s|^/home/[^/]+|~|:pane_current_path}#{?#{E:@git_branch}, #[fg=#{@noctalia_outline}]#{@sep_l_thin}#[fg=#{@noctalia_on_surface_variant}] #{@icon_branch} #{E:@git_branch},} #[fg=#{@noctalia_surface_container_high}]#{@sep_l}#[fg=#{@noctalia_on_surface},bg=#{@noctalia_surface_container_high}] #{@icon_load} #(cut -d" " -f1 /proc/loadavg)  #{@icon_mem} #(awk "/^MemTotal/{t=\$2} /^MemAvailable/{a=\$2} END{printf \"%%d%%%%\", (t-a)*100/t}" /proc/meminfo) #[fg=#{E:@mode_bg}]#{@sep_l}#[fg=#{E:@mode_fg},bg=#{E:@mode_bg},bold] %H:%M  %d %b '

      # renumber windows when you close one. 
      set-option -g renumber-windows on

      # use backtick to switch to marked pane
      bind ` switch-client -t'{marked}'

      # change pane split keys to | and -
      bind | split-window -hc "#{pane_current_path}"
      bind - split-window -vc "#{pane_current_path}"

      # Noctalia theme: palette plus pane-border, menu, message and copy-mode
      # styles. KEEP THIS AS THE LAST LINE, spelled exactly like this: the
      # template's post-hook (apply.sh) rewrites tmux.conf to end with this
      # line and only re-sources the theme into running servers once the
      # file already does. tmux.conf is a read-only store path here, so any
      # difference makes the hook fail before the live reload.
      source-file -q "$HOME/.config/tmux/themes/noctalia.conf"
    '';
  };
}
;
}
