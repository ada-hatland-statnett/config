-- kndndrj/nvim-dbee config
return {
  {
    'kndndrj/nvim-dbee',
    dependencies = { 'MunifTanjim/nui.nvim' },
    build = function() require('dbee').install() end,
    config = function()
      require('dbee').setup(--[[optional config]])
    end,
    keys = {
      { '<leader>p', function() require('dbee').toggle() end, desc = 'Database UI toggle' },
      {
        '<leader>r',
        function() require('dbee').execute(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')) end,
        desc = 'Execute SQL buffer',
        ft = 'sql',
      },
      {
        '<leader>t',
        function()
          local word = vim.fn.expand '<cword>'
          if word == '' then
            vim.notify('No word under cursor', vim.log.levels.WARN)
            return
          end
          -- Look up schema from the blink-dbee cache
          local dbee_cmp = require 'custom.blink-dbee'
          local schema = dbee_cmp.get_schema_for_table(word)
          if not schema then
            vim.notify('Table "' .. word .. '" not found in cache. Try <leader>R to refresh.', vim.log.levels.WARN)
            return
          end
          local query = 'SELECT * FROM ' .. schema .. '.' .. word .. ' FETCH FIRST 50 ROWS ONLY'
          require('dbee').execute(query)
        end,
        desc = 'Preview table under cursor (first 50 rows)',
        ft = 'sql',
      },
      {
        '<leader>R',
        function()
          require('custom.blink-dbee').clear_cache()
          vim.notify 'dbee completion cache cleared'
        end,
        desc = 'Refresh dbee completion cache',
        ft = 'sql',
      },
      {
        '<leader>T',
        function()
          local dbee_cmp = require 'custom.blink-dbee'
          local tables = dbee_cmp.list_tables()
          if not tables or #tables == 0 then
            vim.notify('No tables found. Is dbee connected?', vim.log.levels.WARN)
            return
          end
          vim.ui.select(tables, { prompt = 'Select table to preview:' }, function(choice)
            if not choice then return end
            local query = 'SELECT * FROM ' .. choice .. ' FETCH FIRST 50 ROWS ONLY'
            require('dbee').execute(query)
          end)
        end,
        desc = 'List tables and preview',
        ft = 'sql',
      },
    },
  },
}
