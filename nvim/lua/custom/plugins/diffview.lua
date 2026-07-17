-- diffview plugin configuration
return {
  {
    'sindrets/diffview.nvim',
    config = function()
      local actions = require 'diffview.actions'

      -- Close Diffview and open the real file under the cursor in the file panel.
      local function open_file_under_cursor()
        local lib = require 'diffview.lib'
        local view = lib.get_current_view()
        if not (view and view.panel) then return end

        local item = view.panel:get_item_at_cursor()
        if not (item and item.absolute_path) then
          vim.notify('No file under cursor', vim.log.levels.WARN)
          return
        end

        local path = item.absolute_path
        vim.cmd 'DiffviewClose'
        vim.cmd('edit ' .. vim.fn.fnameescape(path))
      end

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
            { 'n', 'o', open_file_under_cursor, { desc = 'Close Diffview and open file in buffer' } },
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
