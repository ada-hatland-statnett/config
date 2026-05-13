-- diffview plugin configuration
return {
  {
    'sindrets/diffview.nvim',
    config = function()
      local actions = require 'diffview.actions'
      require('diffview').setup {
        keymaps = {
          view = {
            { 'n', 'n', 'j', { desc = 'Move cursor down' } },
            { 'n', 'e', 'k', { desc = 'Move cursor up' } },
            ['N'] = actions.select_next_entry,
            ['E'] = actions.select_prev_entry,
          },
          file_panel = {
            ['n'] = actions.next_entry,
            ['e'] = actions.prev_entry,
          },
        },
      }
      local function toggle_diffview(args)
        local lib = require 'diffview.lib'
        local view = lib.get_current_view()
        if view then
          vim.cmd 'DiffviewClose'
        else
          vim.cmd('DiffviewOpen ' .. (args or ''))
        end
      end
      vim.keymap.set('n', '<leader>gm', function() toggle_diffview 'main' end, { desc = 'Toggle Diffview (master)' })
      vim.keymap.set('n', '<leader>gr', function() toggle_diffview '@{u}..HEAD --cached' end, { desc = 'Toggle Diffview (staged vs remote)' })
      vim.keymap.set('n', '<leader>gu', function() toggle_diffview() end, { desc = 'Toggle Diffview (unstaged)' })
    end,
    dependencies = {
      'nvim-lua/plenary.nvim',
    },
  },
}
