return {
      'nvim-telescope/telescope.nvim', version = '*',
      dependencies = {
          'nvim-lua/plenary.nvim',
          -- optional but recommended
          { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
      },
      config = function()
          local telescope = require('telescope')
          local builtin = require('telescope.builtin')

          telescope.setup({
            defaults = {
              -- Default configuration for telescope goes here:
              -- config_key = value,
            },
            pickers = {
              -- This makes find_files always behave how you want
              find_files = {
                hidden = true,
                no_ignore = true,
                follow = true, -- Also follows those symlinks we discussed!
              },
            },
          })

          -- Your keymaps stay here, but now they use the custom picker defaults
          vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope find files' })
          vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Telescope live grep' })
          vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
          vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })
        end,
}
