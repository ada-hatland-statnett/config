-- kndndrj/nvim-dbee config
return {
  {
    'kndndrj/nvim-dbee',
    dependencies = { 'MunifTanjim/nui.nvim' },
    build = function() require('dbee').install() end,
    config = function()
      require('dbee').setup(--[[optional config]])

      local function resize_result_window(win)
        if not win or not vim.api.nvim_win_is_valid(win) then return end
        if vim.api.nvim_win_get_config(win).relative ~= '' then return end

        local rows_for_temp_query = 8
        local available_rows = vim.o.lines - vim.o.cmdheight

        if vim.o.laststatus > 0 then available_rows = available_rows - 1 end

        local showtabline = vim.o.showtabline
        if showtabline == 2 or (showtabline == 1 and #vim.api.nvim_list_tabpages() > 1) then
          available_rows = available_rows - 1
        end

        local target_height = math.max(1, available_rows - rows_for_temp_query)
        pcall(vim.api.nvim_win_set_height, win, target_height)
      end

      -- Buffer-local keymaps in the dbee result view. Scoped by buffer name
      -- because the "dbee" filetype is shared with editor buffers.
      vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter' }, {
        callback = function(ev)
          local name = vim.api.nvim_buf_get_name(ev.buf)
          if name:match 'dbee%-result' then
            local preview = function() return require 'custom.dbee-preview' end
            vim.keymap.set('n', '<leader>f', function() preview().filter_column() end, {
              buffer = ev.buf,
              desc = 'Filter previewed table by column under cursor',
            })
            vim.keymap.set('n', '<leader>m', function() preview().load_next() end, {
              buffer = ev.buf,
              desc = 'Load next 50 rows',
            })
            vim.keymap.set('n', '<leader>M', function() preview().load_prev() end, {
              buffer = ev.buf,
              desc = 'Load previous 50 rows',
            })
            -- keep the column header pinned while scrolling
            preview().enable_sticky_header(ev.buf)

            local win = vim.fn.bufwinid(ev.buf)
            if win ~= -1 then vim.schedule(function() resize_result_window(win) end) end
          end
        end,
      })

      vim.api.nvim_create_autocmd('VimResized', {
        callback = function()
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            local name = vim.api.nvim_buf_get_name(buf)
            if name:match 'dbee%-result' then resize_result_window(win) end
          end
        end,
      })
    end,
    keys = {
      { '<leader>D', function() require('dbee').toggle() end, desc = 'Database UI toggle' },
      {
        '<leader>r',
        function() require('custom.dbee-runner').run_buffer() end,
        desc = 'Execute SQL buffer (reports failing line)',
        ft = 'sql',
      },
      {
        '<leader>r',
        function() require('custom.dbee-runner').run_selection() end,
        mode = 'x',
        desc = 'Execute selected SQL',
        ft = 'sql',
      },
      {
        '<leader>t',
        function() require('custom.dbee-preview').preview_under_cursor() end,
        desc = 'Preview table under cursor (first 50 rows)',
        ft = 'sql',
      },
      {
        '<leader>R',
        function()
          require('custom.blink-dbee').clear_cache()
          vim.notify 'Table cache cleared (columns.json preserved)'
        end,
        desc = 'Clear table cache',
        ft = 'sql',
      },
      {
        '<leader>T',
        function() require('custom.dbee-preview').preview_pick() end,
        desc = 'List tables and preview',
        ft = 'sql',
      },
      {
        '<leader>l',
        function() require('custom.dbee-preview').find_column(false) end,
        desc = 'Find column (cached)',
        ft = 'sql',
      },
      {
        '<leader>L',
        function() require('custom.dbee-preview').find_column(true) end,
        desc = 'Find column (re-fetch from DB)',
        ft = 'sql',
      },
    },
  },
}
