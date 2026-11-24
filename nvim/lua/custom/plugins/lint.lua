return {
  {
    'mfussenegger/nvim-lint',
    ft = 'kotlin',
    config = function()
      local lint = require 'lint'
      lint.linters.teamcity = require 'custom.teamcity-linter'
      -- Give ktlint the real path for script parsing and project .editorconfig rules.
      table.insert(lint.linters.ktlint.args, function() return '--stdin-path=' .. vim.api.nvim_buf_get_name(0) end)
      vim.api.nvim_create_autocmd('BufWritePost', {
        group = vim.api.nvim_create_augroup('kotlin-lint', { clear = true }),
        pattern = { '*.kt', '*.kts' },
        callback = function(event)
          vim.api.nvim_buf_call(event.buf, function()
            if vim.fn.executable 'ktlint' == 1 then lint.try_lint 'ktlint' end
            local path = vim.api.nvim_buf_get_name(event.buf)
            if path:match('/%.teamcity/settings%.kts$') and vim.uv.fs_stat(vim.fs.dirname(path) .. '/pom.xml') then
              lint.try_lint 'teamcity'
            end
          end)
        end,
      })
    end,
  },
}
