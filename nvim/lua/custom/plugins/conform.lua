-- conform.nvim setup
return {
  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function() require('conform').format { async = true, lsp_format = 'fallback' } end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    opts = {
      notify_on_error = false,
      format_on_save = function(bufnr)
        local disable_filetypes = { c = true, cpp = true }
        if disable_filetypes[vim.bo[bufnr].filetype] then
          return nil
        else
          return {
            timeout_ms = 5000,
            lsp_format = 'fallback',
          }
        end
      end,
      formatters_by_ft = {
        lua = { 'stylua' },
        python = { 'ruff_format', 'ruff_organize_imports' },
        sql = { 'sqlfluff' },
        yaml = { 'prettier' },
      },
      formatters = {
        -- Max line width 80 for every formatter below.
        stylua = {
          prepend_args = { '--column-width', '80' },
        },
        ruff_format = {
          prepend_args = { '--line-length', '80' },
        },
        prettier = {
          prepend_args = { '--print-width', '80' },
        },
        sqlfluff = {
          command = 'sqlfluff',
          args = {
            'format',
            '--dialect',
            'oracle',
            '--config',
            vim.fn.stdpath 'config' .. '/.sqlfluff',
            '-',
          },
          stdin = true,
          cwd = function() return vim.fn.getcwd() end,
        },
      },
    },
  },
}
