{ pkgs, ... }:

{
  programs.bash.enable = true;

  home.shellAliases = {
    nv = "nvim";
    cc = "claude";
    vsc = "code";
    
    #git
    gst = "git status";
    glo = "git log --graph";
    gad = "git add -A";
    gco = "git commit -m";
    gpub = "git push --set-upstream origin $(git branch --show-current)";
    gs = "git stash";
  };

  programs.bash.initExtra = ''
    mkcd() {
      mkdir -p "$1" && cd "$1"
    }

    # Prompt: [\u@\h:\w] shape and title-bar behavior as NixOS's default
    # (nixos/modules/programs/bash/bash.nix promptInit), with the current
    # git branch appended right before the prompt character when the cwd is
    # inside a repo. __git_ps1 comes from git's own contrib script rather
    # than a hand-rolled check, so detached HEAD/rebase/merge states are
    # reported correctly too.
    source "${pkgs.git}/share/git/contrib/completion/git-prompt.sh"

    if [ "$TERM" != "dumb" ] || [ -n "$INSIDE_EMACS" ]; then
      PROMPT_COLOR="1;31m"
      ((UID)) && PROMPT_COLOR="1;32m"
      if [ -n "$INSIDE_EMACS" ]; then
        PS1="\n\[\033[$PROMPT_COLOR\][\u@\h:\w]\$(__git_ps1 ' (%s)')\\$\[\033[0m\] "
      else
        PS1="\n\[\033[$PROMPT_COLOR\][\[\e]0;\u@\h: \w\a\]\u@\h:\w]\$(__git_ps1 ' (%s)')\\$\[\033[0m\] "
      fi
      if test "$TERM" = "xterm"; then
        PS1="\[\033]2;\h:\u:\w\007\]$PS1"
      fi
    fi
  '';
}
