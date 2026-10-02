# zsh, the login shell (set in modules/users/shashin/user.nix). bash stays
# configured in bash.nix as a fallback.
#
# Aliases are NOT defined here: home.shellAliases (bash.nix) is applied to
# every enabled shell, so sc/pj/git/etc. stay in one place for both. The git
# aliases stay as they are rather than switching to oh-my-zsh's git plugin
# (the usual "zsh way"): that plugin brings ~200 aliases, needs an OMZ-style
# plugin loader, and reassigns names already in use here (its gco is
# `git checkout`, not `git commit -m`). zsh completes through aliases
# anyway, so `gco <Tab>` and friends complete like the git subcommand.
{
  flake.modules.homeManager.shashin =
    { pkgs, ... }:
    {
      programs.zsh = {
        enable = true;

        # The two plugins: fish-style grey suggestions from history (accept
        # with Right/End), and live command highlighting (red = not found).
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;

        # zsh picks vi mode when EDITOR contains "vi" (EDITOR=nvim here);
        # keep the emacs-style line editing bash/readline had.
        defaultKeymap = "emacs";

        history = {
          size = 50000;
          save = 50000;
          share = true; # live across open terminals
          ignoreAllDups = true;
          ignoreSpace = true; # leading space = keep out of history
          extended = true; # record timestamps
        };

        # ~sc, ~pj work in any path argument and show in the prompt. With
        # AUTO_CD, `~pj/venk<Tab>` + Enter replaces bash.nix's `p` function.
        dirHashes = {
          sc = "$HOME/system-configs";
          pj = "$HOME/Projects";
        };

        setOptions = [
          "AUTO_CD" # a bare directory name cd's into it
          "AUTO_PUSHD" # every cd pushes; `cd -<Tab>` lists recent dirs
          "PUSHD_IGNORE_DUPS"
          "PUSHD_SILENT"
          "INTERACTIVE_COMMENTS" # allow `# ...` at the prompt, as bash does
          "PROMPT_SUBST" # needed by __git_ps1 in PS1
        ];
        # EXTENDED_GLOB deliberately left off: it makes `#` a glob operator,
        # which breaks unquoted flake refs like `nix shell nixpkgs#foo`.

        initContent = ''
          # Completion: arrow-key menu, case-insensitive matching, ls colors.
          zstyle ':completion:*' menu select
          zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
          zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"

          # Up/Down search history for lines starting with what's typed.
          autoload -U up-line-or-beginning-search down-line-or-beginning-search
          zle -N up-line-or-beginning-search
          zle -N down-line-or-beginning-search
          for k in '^[[A' '^[OA'; do bindkey "$k" up-line-or-beginning-search; done
          for k in '^[[B' '^[OB'; do bindkey "$k" down-line-or-beginning-search; done

          mkcd() {
            mkdir -p "$1" && cd "$1"
          }

          stress-cores() {
            nix-shell -p stress-ng --run 'stress-ng --cpu $(nproc) --cpu-load 20 --timeout 5s && stress-ng --cpu $(nproc) --cpu-load 60 --timeout 5s'
          }

          # Prompt: the bash prompt's [user@host:cwd] (branch)$ shape, green
          # (red for root), via git's own git-prompt.sh, which supports zsh.
          source "${pkgs.git}/share/git/contrib/completion/git-prompt.sh"
          PS1=$'\n%B%(!.%F{red}.%F{green})[%n@%m:%~]$(__git_ps1 " (%s)")%(!.#.$)%f%b '

          # Window title: user@host: cwd, as bash's prompt set it.
          _title_precmd() { print -Pn '\e]0;%n@%m: %~\a' }
          precmd_functions+=(_title_precmd)
        '';
      };
    };
}
