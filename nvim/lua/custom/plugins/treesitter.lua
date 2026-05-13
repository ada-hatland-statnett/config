-- nvim-treesitter configuration
return {
  {
    'nvim-treesitter/nvim-treesitter',
    config = function()
      local filetypes = { 'bash', 'c', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc', 'sql', 'python' }
      require('nvim-treesitter').setup {
        highlight = { enable = true },
        indent = { enable = true },
        ensure_installed = filetypes,
        auto_install = true,
      }
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
