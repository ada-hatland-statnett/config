-- kndndrj/nvim-dbee config
return {
  {
    'kndndrj/nvim-dbee',
    dependencies = { 'MunifTanjim/nui.nvim' },
    build = function() require('dbee').install() end,
    config = function()
      require('dbee').setup(--[[optional config]])

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
          end
        end,
      })
    end,
    keys = {
      { '<leader>p', function() require('dbee').toggle() end, desc = 'Database UI toggle' },
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
