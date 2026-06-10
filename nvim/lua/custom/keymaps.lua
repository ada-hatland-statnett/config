-- Keymaps
-- See `:help vim.keymap.set()`

-- Clear highlights on search
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostics
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })
vim.keymap.set('n', '?', vim.lsp.buf.hover, { desc = 'Show documentation for word under cursor' })

-- Terminal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Window navigation (CTRL+hjkl)
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-n>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-e>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- Search next/prev on t / T
vim.keymap.set('n', 't', 'n', { noremap = true, silent = true })
vim.keymap.set('n', 'T', 'N', { noremap = true, silent = true })

-- Colemak-style: n -> j (down), e -> k (up)
vim.keymap.set({ 'n', 'x', 'o' }, 'n', 'j', { remap = true, silent = true })
vim.keymap.set({ 'n', 'x', 'o' }, 'e', 'k', { remap = true, silent = true })

-- Paragraph jump on N/E
vim.keymap.set({ 'n', 'x', 'o' }, 'N', '}', { remap = true, silent = true })
vim.keymap.set({ 'n', 'x', 'o' }, 'E', '{', { remap = true, silent = true })

-- Custom movement
vim.keymap.set({ 'n', 'x', 'o' }, 'W', 'b')
vim.keymap.set('n', 'H', '<cmd>bprevious<cr>', { desc = 'Buffer: previous' })
vim.keymap.set('n', 'L', '<cmd>bnext<cr>', { desc = 'Buffer: next' })

-- Save / Quit / Buffer
vim.keymap.set({ 'n', 'x' }, 'S', '<cmd>write<cr>', { silent = true, desc = 'Save file' })
vim.keymap.set('n', 'M', function() vim.cmd 'q' end, { silent = true, desc = 'Quit Neovim' })
vim.keymap.set('n', '<leader>d', '<cmd>bdelete<cr>', { desc = 'Buffer: delete' })
vim.keymap.set('n', 'U', '<C-r>', { noremap = true, silent = true })

-- Telescope live grep
vim.keymap.set('n', '<leader>sg', ":lua require('telescope').extensions.live_grep_args.live_grep_args()<CR>")

-- Search and replace
vim.keymap.set('n', '<leader>S', ':%s/<C-r>///gc<Left><Left><Left>', { desc = 'Search and replace' })
vim.keymap.set('v', '<leader>S', ':s/<C-r>///gc<Left><Left><Left>', { desc = 'Search and replace' })

-- Run current file (filetype-dependent, set in functions.lua)
vim.keymap.set('n', '<leader>r', function() require('custom.functions').run_current_file() end, { desc = 'Run current file' })
