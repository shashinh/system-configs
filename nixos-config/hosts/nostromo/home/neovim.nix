{ pkgs, ... }:

# Plugins normally come from pkgs.vimPlugins.<name> (nixpkgs' curated,
# auto-generated plugin set). If something isn't packaged there yet, package
# it inline instead of waiting for it to be added upstream:
#
#   pkgs.vimUtils.buildVimPlugin {
#     pname = "some-plugin";
#     version = "unstable-2026-01-01";
#     src = pkgs.fetchFromGitHub {
#       owner = "someone";
#       repo = "some-plugin.nvim";
#       rev = "abc123...";
#       hash = "sha256-...";  # nix tells you the right value on first build
#     };
#   }
#
# That derivation drops straight into the `plugins` list below, bare or
# wrapped in { plugin = ...; config = "..."; type = "lua"; }, same as any
# pkgs.vimPlugins entry. Works for both vimscript and Lua plugins.
#
# Updating a plugin:
# - pkgs.vimPlugins.<name> entries: there's no per-plugin update — the
#   version is whatever's pinned by your `nixpkgs` flake input. Bump it with
#   `nix flake update nixpkgs` (or `nix flake lock --update-input nixpkgs`)
#   from nixos-config's root, then rebuild. Note this updates every package
#   pinned to that input, not just this one plugin — there's no flake-style
#   `follows` mechanism for a single attribute inside one nixpkgs checkout.
# - buildVimPlugin entries above: bump `rev` to the commit you want, then
#   set `hash` to an obviously-wrong placeholder (e.g. "") and rebuild —
#   Nix's error message reports the correct hash to paste in. `nix-prefetch-github
#   owner repo --rev <rev>` gets you the same hash without the fail-first step.
{
  programs.neovim = {
    enable = true;

    extraPackages = with pkgs; [
      ripgrep # backs telescope's live_grep
    ];

    initLua = ''
      vim.cmd("set expandtab")
      vim.cmd("set tabstop=2")
      vim.cmd("set softtabstop=2")
      vim.cmd("set shiftwidth=2")
      vim.cmd("set nu")
      vim.cmd("set nocompatible")
      vim.cmd("set showmatch")
      vim.cmd("set ignorecase")
      vim.cmd("set mouse=v")
      vim.cmd("set hlsearch")
      vim.cmd("set incsearch")
      vim.cmd("set wildmode=longest,list")
      vim.cmd("set cc=80")

      vim.g.mapleader = " "
      vim.g.maplocalleader = "\\"
    '';

    plugins = with pkgs.vimPlugins; [
      {
        plugin = catppuccin-nvim;
        type = "lua";
        config = ''
          require("catppuccin").setup({
            color_overrides = {
              mocha = {
                base = "#000000",
                mantle = "#000000",
                crust = "#000000",
              },
            },
          })
          vim.cmd.colorscheme("catppuccin-mocha")
        '';
      }

      nvim-web-devicons

      {
        plugin = lualine-nvim;
        type = "lua";
        config = ''
          require('lualine').setup({})
        '';
      }

      plenary-nvim
      nui-nvim

      {
        plugin = neo-tree-nvim;
        type = "lua";
        config = ''
          vim.keymap.set('n', '<C-n>', ':Neotree filesystem toggle left<CR>')

          -- Quit nvim if neo-tree is the last window left open, instead of
          -- leaving a sidebar-only session behind after closing the last file.
          vim.api.nvim_create_autocmd('QuitPre', {
            callback = function()
              local tree_wins = {}
              local floating_wins = {}
              local wins = vim.api.nvim_list_wins()
              for _, w in ipairs(wins) do
                local bufname = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w))
                if bufname:match("neo%-tree") ~= nil then
                  table.insert(tree_wins, w)
                end
                if vim.api.nvim_win_get_config(w).relative ~= '' then
                  table.insert(floating_wins, w)
                end
              end
              if 1 == #wins - #floating_wins - #tree_wins then
                for _, w in ipairs(tree_wins) do
                  vim.api.nvim_win_close(w, true)
                end
              end
            end,
          })
        '';
      }

      telescope-fzf-native-nvim

      {
        plugin = telescope-nvim;
        type = "lua";
        config = ''
          local telescope = require('telescope')
          local builtin = require('telescope.builtin')

          telescope.setup({
            defaults = {},
            pickers = {
              find_files = {
                hidden = true,
                no_ignore = true,
                follow = true,
              },
            },
          })

          vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope find files' })
          vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Telescope live grep' })
          vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
          vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })
        '';
      }

      # nvim-treesitter's "main" branch (current upstream default, and what
      # nixpkgs packages) dropped the old ensure_installed/highlight.enable
      # setup and doesn't auto-start anything — and its withPlugins bundling
      # helper is broken for this branch (builds fine, silently ships zero
      # parsers, confirmed by building it and finding no parser/ dir at all).
      # The working approach: pull the compiled grammar in separately from
      # nvim-treesitter-parsers (nixpkgs' per-language grammar packages,
      # ABI-matched to this nvim-treesitter version) and start Treesitter
      # per-filetype yourself, per nvim-treesitter's own README.
      # lua isn't listed below on purpose: Neovim core bundles the lua
      # grammar itself and ftplugin/lua.lua already calls
      # vim.treesitter.start() automatically — nothing to add for it.
      nvim-treesitter-parsers.nix
      nvim-treesitter-parsers.java
      nvim-treesitter-parsers.c
      nvim-treesitter-parsers.cpp
      nvim-treesitter-parsers.rust
      nvim-treesitter-parsers.python

      {
        plugin = nvim-treesitter;
        type = "lua";
        config = ''
          -- The plugin keeps queries/ftplugin/syntax nested under runtime/
          -- rather than at the package root, so home-manager's plugin
          -- linking (which only exposes the top level) never surfaces
          -- queries/<lang>/highlights.scm on its own — highlighting then
          -- silently attaches with zero captures, no error anywhere.
          -- Confirmed with a headless nvim test before/after this line.
          vim.opt.rtp:append("${nvim-treesitter}/runtime")

          -- C already gets highlighting (syntax/c.vim) and indentation
          -- (indent/c.vim, i.e. 'cindent') from Neovim core without any of
          -- this — it's included here anyway for parity with cpp, since
          -- switching it to Treesitter overrides both of those with the
          -- structural versions. cindent is mature; Treesitter's indent
          -- module is upstream-labeled experimental, so if C's indent ever
          -- feels worse than before this is the line to remove.
          vim.api.nvim_create_autocmd('FileType', {
            pattern = { 'nix', 'java', 'c', 'cpp', 'rust', 'python' },
            callback = function()
              vim.treesitter.start()
              vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            end,
          })
        '';
      }

      {
        plugin = bufdelete-nvim;
        type = "lua";
        config = ''
          -- :Bdelete / <leader>bd close the current buffer without collapsing
          -- the window (unlike :bw, which hands the freed space to whatever
          -- window is left — e.g. neo-tree filling the screen).
          vim.keymap.set('n', '<leader>bd', ':Bdelete<CR>', { desc = 'Delete buffer, keep window' })
        '';
      }
    ];
  };
}
