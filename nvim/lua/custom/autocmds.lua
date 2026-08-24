-- Autocommands
-- See `:help lua-guide-autocommands`

-- Highlight when yanking text
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function() vim.hl.on_yank() end,
})

-- Open Neotree on startup if no file arguments
vim.api.nvim_create_autocmd('VimEnter', {
  callback = function()
    if vim.fn.argc() == 0 then
      if vim.fn.exists 'g:started_by_firenvim' == 1 then return end
      vim.cmd 'Neotree toggle'
    end
  end,
})

-- Python-specific keymaps
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'python',
  callback = function(ev)
    vim.keymap.set('n', '<leader>F', function() require('custom.functions').py_print_to_fstring() end, {
      buffer = ev.buf,
      desc = 'Python: print(x) -> print(f"{x=}")',
    })
  end,
})

-- Python syntax highlights
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'python',
  callback = function()
    vim.api.nvim_set_hl(0, 'pythonInclude', { fg = '#c678dd', bold = true })
    vim.api.nvim_set_hl(0, '@module.python', { fg = '#e5c07b' })
    vim.api.nvim_set_hl(0, 'pythonComment', { fg = '#a0a0a0' })
  end,
})

-- SQL indentation: 2 spaces per tab/indent level
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'sql',
  callback = function()
    vim.opt_local.expandtab = true
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.softtabstop = 4
  end,
})
