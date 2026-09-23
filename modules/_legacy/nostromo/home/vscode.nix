{ pkgs, ... }:

{
  programs.vscode = {
    enable = true;

    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        vscodevim.vim
      ];

      userSettings = {
        "editor.renderWhitespace" = "all";
        "editor.minimap.enabled" = false;
        "git.openRepositoryInParentFolders" = "never";
        "cmake.configureOnOpen" = true;
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
        "cmake.pinnedCommands" = [
          "workbench.action.tasks.configureTaskRunner"
          "workbench.action.tasks.runTask"
        ];
        "makefile.configureOnOpen" = false;
        "files.autoSave" = "afterDelay";
        "files.watcherExclude" = {
          "**/.bloop" = true;
          "**/.metals" = true;
          "**/.ammonite" = true;
        };
        "rust-analyzer.cargo.features" = "all";
        "rust-analyzer.check.features" = "all";
        "rust-analyzer.cargo.cfgs" = [ "debug_assertions" "miri" "dev-graph" ];
        "workbench.sideBar.location" = "right";
        "dev.containers.dockerPath" = "podman";
        "workbench.startupEditor" = "none";
        "workbench.tree.indent" = 17;
        "workbench.colorTheme" = "NoctaliaTheme";
        "workbench.colorCustomizations" = { };
        "github.copilot.nextEditSuggestions.enabled" = true;

        "editor.wordWrap" = "on";
        "editor.lineNumbers" = "relative";
        "editor.cursorSurroundingLines" = 8;
        "vim.leader" = "<Space>";
        "vim.hlsearch" = true;
        "vim.inccommand" = "replace";
        "vim.visualModeKeyBindings" = [
          { before = [ "<" ]; commands = [ "editor.action.outdentLines" ]; }
          { before = [ ">" ]; commands = [ "editor.action.indentLines" ]; }
          # Move selected lines while staying in visual mode
          { before = [ "J" ]; commands = [ "editor.action.moveLinesDownAction" ]; }
          { before = [ "K" ]; commands = [ "editor.action.moveLinesUpAction" ]; }
          # toggle comment selection
          { before = [ "leader" "c" ]; commands = [ "editor.action.commentLine" ]; }
          { before = [ "leader" "C" ]; commands = [ "editor.action.blockComment" ]; }
          { before = [ "leader" "shift" "/" ]; commands = [ "editor.action.blockComment" ]; }
          { before = [ "<Space>" "s" ]; after = [ ":" "s" "/" ]; }
        ];

        "vim.normalModeKeyBindingsNonRecursive" = [
          # mouse replacement keybindings
          { before = [ "leader" "h" ]; commands = [ "workbench.action.focusLeftGroup" ]; }
          { before = [ "leader" "j" ]; commands = [ "workbench.action.focusBelowGroup" ]; }
          { before = [ "leader" "k" ]; commands = [ "workbench.action.focusAboveGroup" ]; }
          { before = [ "leader" "l" ]; commands = [ "workbench.action.focusRightGroup" ]; }
          # show hover
          { before = [ "leader" "K" ]; commands = [ "editor.action.showHover" ]; }

          # tabs
          # switch between tabs:
          { before = [ "<S-l" ]; commands = [ "workbench.action.nextEditor" ]; }
          { before = [ "<S-h>" ]; commands = [ "workbench.action.previousEditor" ]; }
          # or Vim's ":bprevious" and ":bnext"

          # switch between tabs in the same group:
          { before = [ "<S-l>" ]; commands = [ "workbench.action.nextEditorInGroup" ]; }
          { before = [ "<S-h>" ]; commands = [ "workbench.action.previousEditorInGroup" ]; }
          # VSCode has a shortcut for opening a specific tab in group
          # { key = "alt+1"; command = "workbench.action.openEditorAtIndex1"; }

          # Go to Definition
          { before = [ "g" "d" ]; commands = [ "editor.action.goToDefinition" ]; }
          # Peek Definition
          { before = [ "g" "p" "d" ]; commands = [ "editor.action.peekDefinition" ]; }
          # Show Hover
          { before = [ "g" "h" ]; commands = [ "editor.action.showDefinitionPreviewHover" ]; }
          # Go to Implementations
          { before = [ "g" "i" ]; commands = [ "editor.action.goToImplementation" ]; }
          # Peek Implementations
          { before = [ "g" "p" "i" ]; commands = [ "editor.action.peekImplementation" ]; }
          # Go to References
          { before = [ "g" "r" ]; commands = [ "editor.action.referenceSearch.trigger" ]; }
          # Go to Type Definition
          { before = [ "g" "t" ]; commands = [ "editor.action.goToTypeDefinition" ]; }
          # Peek Type Definition
          { before = [ "g" "p" "t" ]; commands = [ "editor.action.peekTypeDefinition" ]; }

          # remove conflict with Vim Ctrl+E
          { before = [ "leader" "e" ]; commands = [ "workbench.action.quickOpen" ]; }
          { before = [ "leader" "q" ]; commands = [ "workbench.action.closeActiveEditor" ]; }
        ];
        "claudeCode.preferredLocation" = "panel";
        "terminal.integrated.gpuAcceleration" = "off";
        "redhat.telemetry.enabled" = false;
      };

      keybindings = [
        { key = "alt+b"; command = "workbench.action.toggleSidebarVisibility"; }
        { key = "ctrl+b"; command = "-workbench.action.toggleSidebarVisibility"; }
        {
          key = "shift+alt+v";
          command = "workbench.action.editorDictation.start";
          when = "hasSpeechProvider && !editorDictation.inProgress && !editorReadonly";
        }
        {
          key = "ctrl+alt+v";
          command = "-workbench.action.editorDictation.start";
          when = "hasSpeechProvider && !editorDictation.inProgress && !editorReadonly";
        }
        { key = "ctrl+alt+v"; command = "toggleVim"; }
        {
          # quickfix
          key = "ctrl+.";
          command = "editor.action.quickFix";
          when = "editorHasCodeActionsProvider && textInputFocus && !editorReadonly";
        }
        { key = "h"; command = "editor.action.scrollLeftHover"; when = "editorHoverFocused"; }
        { key = "j"; command = "editor.action.scrollDownHover"; when = "editorHoverFocused"; }
        { key = "k"; command = "editor.action.scrollUpHover"; when = "editorHoveredFocused"; }
        { key = "l"; command = "editor.action.scrollRightHover"; when = "editorHoverFocused"; }
        { key = "ctrl+h"; command = "actions.find"; when = "editorFocus && editorIsOpen"; }
        {
          key = "ctrl+h";
          command = "closeFindWidget";
          when = "editorFocus && editorIsOpen && findWidgetVisible";
        }
        {
          key = "ctrl+shift+h";
          command = "editor.action.startFindReplaceAction";
          when = "editorFocus && editorIsOpen";
        }
        {
          key = "ctrl+n";
          command = "editor.action.nextMatchFindAction";
          when = "editorFocus && findWidgetVisible";
        }
        {
          key = "ctrl+p";
          command = "editor.action.previousMatchFindAction";
          when = "editorFocus && findWidgetVisible";
        }
        { key = "ctrl+shift+t"; command = "workbench.action.togglePanel"; }
        {
          key = "ctrl+shift+n";
          command = "workbench.action.terminal.new";
          when = "terminalIsOpen && terminalFocus";
        }
        {
          key = "ctrl+n";
          command = "workbench.action.terminal.focusNext";
          when = "terminalIsOpen && terminalFocus";
        }
        {
          key = "ctrl+p";
          command = "workbench.action.terminal.focusPrevious";
          when = "terminalIsOpen && terminalFocus";
        }
        {
          key = "ctrl+q";
          command = "workbench.action.terminal.kill";
          when = "terminalIsOpen && terminalFocus";
        }
        # EXPLORER
        { key = "ctrl+shift+e"; command = "workbench.view.explorer"; }
        { key = "n"; command = "explorer.newFile"; when = "filesExplorerFocus && !inputFocus"; }
        { key = "shift+n"; command = "explorer.newFolder"; when = "filesExplorerFocus && !inputFocus"; }
        { key = "x"; command = "filesExplorer.cut"; when = "filesExplorerFocus && !inputFocus"; }
        { key = "p"; command = "filesExplorer.paste"; when = "filesExplorerFocus && !inputFocus"; }
        { key = "d"; command = "deleteFile"; when = "filesExplorerFocus && !inputFocus"; }
        # GIT
        { key = "ctrl+shift+g"; command = "workbench.view.scm"; }
        {
          key = "ctrl+s";
          command = "git.stage";
          when = "activeViewlet == 'workbench.view.scm' && sideBarFocus";
        }
        {
          key = "ctrl+u";
          command = "git.unstage";
          when = "activeViewlet == 'workbench.view.scm' && sideBarFocus";
        }
        {
          key = "ctrl+c";
          command = "git.commitAllSigned";
          when = "activeViewlet == 'workbench.view.scm' && sideBarFocus";
        }
        {
          key = "ctrl+p";
          command = "git.push";
          when = "activeViewlet == 'workbench.view.scm' && sideBarFocus";
        }
        {
          key = "shift+enter";
          command = "workbench.action.terminal.sendSequence";
          # ESC (0x1b) + CR: Nix string literals have no \u escape,
          # so parse it out of a JSON literal instead of typing the raw
          # control bytes into the file.
          args.text = builtins.fromJSON ''"\u001b\r"'';
          when = "terminalFocus";
        }
        # {
        #   key = "ctrl+l";
        #   command = "ctrl+l";
        #   when = "terminalFocus";
        # }
      ];
    };
  };
}
