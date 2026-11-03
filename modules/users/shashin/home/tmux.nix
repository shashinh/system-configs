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

      # customize status bar colors
      ## status bar bg/fg
      set -g status-style bg=default
      set -g status-fg brightblack
      ## inactive
      set -g window-status-style bg=brightblack,fg=black
      ## active
      set -g window-status-current-style bg=brightgreen,fg=black

      # renumber windows when you close one. 
      set-option -g renumber-windows on

      # use backtick to switch to marked pane
      bind ` switch-client -t'{marked}'

      # change pane split keys to | and -
      bind | split-window -hc "#{pane_current_path}"
      bind - split-window -vc "#{pane_current_path}"
    '';
  };
}
;
}
