-- nvim-treesitter configuration
return {
  {
    'nvim-treesitter/nvim-treesitter',
    config = function()
      local filetypes = { 'bash', 'c', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc', 'sql', 'python' }
      -- nvim-treesitter `main` ignores ensure_installed/highlight options;
      -- parsers must be installed explicitly (no-op if already present).
      require('nvim-treesitter').setup {}
      require('nvim-treesitter').install(filetypes)
      vim.api.nvim_create_autocmd('FileType', {
        pattern = filetypes,
        callback = function()
          local ok, err = pcall(vim.treesitter.start)
          if not ok then vim.notify('Treesitter parser not available: ' .. tostring(err), vim.log.levels.WARN) end
        end,
      })
    end,
  },
}
