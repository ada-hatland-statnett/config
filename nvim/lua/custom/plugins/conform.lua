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
      notify_on_error = true,
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
        -- Max line width 80 for the formatters below. Python is the exception
        -- at 88 (ruff's default) -- see the note further down.
        stylua = {
          prepend_args = { '--column-width', '80' },
        },
        -- NOTE: ruff takes no line-length flag here. `prepend_args` inserts
        -- before conform's own args, producing `ruff --line-length 80 format
        -- ...`, and ruff requires the subcommand first -- so the whole
        -- invocation errors out and nothing is formatted. Line length for both
        -- ruff_format and ruff_organize_imports is 88, set in
        -- ~/.config/ruff/ruff.toml.
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
