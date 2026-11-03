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

      local function git_on_item(build_cmd)
        local view = require('diffview.lib').get_current_view()
        if not (view and view.panel) then return end
        local item = view.panel:get_item_at_cursor()
        if not (item and item.path) then
          vim.notify('No file under cursor', vim.log.levels.WARN)
          return
        end
        local cmd = build_cmd(item)
        if not cmd then return end
        local out = vim.fn.system(vim.list_extend({ 'git', '-C', view.adapter.ctx.toplevel }, cmd))
        if vim.v.shell_error ~= 0 then
          vim.notify(out, vim.log.levels.ERROR)
          return
        end
        view:update_files()
      end

      local function git_add()
        git_on_item(function(item) return { 'add', '--', item.path } end)
      end

      local function git_restore()
        git_on_item(function(item)
          if item.kind ~= 'working' then
            vim.notify('Restore only works on unstaged changes', vim.log.levels.WARN)
            return nil
          end
          if vim.fn.confirm('Discard unstaged changes to ' .. item.path .. '?', '&Yes\n&No', 2) ~= 1 then return nil end
          return { 'restore', '--', item.path }
        end)
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
            { 'n', 'a', git_add, { desc = 'git add file under cursor' } },
            { 'n', 'r', git_restore, { desc = 'git restore file under cursor (unstaged only)' } },
            { 'n', '<esc>', '<cmd>DiffviewClose<cr>', { desc = 'Close Diffview' } },
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
