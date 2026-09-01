-- Keymaps
-- See `:help vim.keymap.set()`

-- Clear highlights on search
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostics
vim.keymap.set(
  'n',
  '<leader>q',
  vim.diagnostic.setloclist,
  { desc = 'Open diagnostic [Q]uickfix list' }
)
vim.keymap.set(
  'n',
  '?',
  vim.lsp.buf.hover,
  { desc = 'Show documentation for word under cursor' }
)

-- Terminal mode
vim.keymap.set('t', '<Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Buffer switching (CTRL+h/l) in all modes
vim.keymap.set(
  { 'n', 'i', 'v', 'x', 's', 'o', 't' },
  '<C-h>',
  '<cmd>bprevious<cr>',
  { desc = 'Buffer: previous', silent = true }
)
vim.keymap.set(
  { 'n', 'i', 'v', 'x', 's', 'o', 't' },
  '<C-l>',
  '<cmd>bnext<cr>',
  { desc = 'Buffer: next', silent = true }
)

-- Window navigation (CTRL+n/e)
vim.keymap.set(
  'n',
  '<C-n>',
  '<C-w><C-j>',
  { desc = 'Move focus to the lower window' }
)
vim.keymap.set(
  'n',
  '<C-e>',
  '<C-w><C-k>',
  { desc = 'Move focus to the upper window' }
)

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

-- Save / Quit / Buffer
vim.keymap.set(
  { 'n', 'x' },
  'S',
  '<cmd>write<cr>',
  { silent = true, desc = 'Save file' }
)
vim.keymap.set(
  'n',
  'M',
  function() vim.cmd 'q' end,
  { silent = true, desc = 'Quit Neovim' }
)
vim.keymap.set('n', '<leader>d', function()
  local pid = vim.b.terminal_job_pid
  if pid then
    -- Terminal buffer: only prompt if the shell has a running child process.
    local children =
      vim.fn.readfile('/proc/' .. pid .. '/task/' .. pid .. '/children')
    local has_child = children[1] and children[1]:match '%S' ~= nil
    vim.cmd(has_child and 'bdelete' or 'bdelete!')
  else
    vim.cmd 'bdelete'
  end
end, { desc = 'Buffer: delete' })
vim.keymap.set('n', '<leader>t', function()
  -- Leave special windows (neo-tree, etc.) before opening the terminal.
  if vim.bo.buftype ~= '' then vim.cmd 'wincmd p' end
  if vim.bo.buftype ~= '' then vim.cmd 'new' end
  vim.cmd 'enew'
  vim.cmd 'terminal'
end, { desc = 'Open terminal' })
vim.keymap.set('n', 'U', '<C-r>', { noremap = true, silent = true })

-- Make `c` (change) not touch the clipboard/registers (send to black hole)
vim.keymap.set({ 'n', 'x' }, 'c', '"_c', { noremap = true, silent = true })
vim.keymap.set({ 'n', 'x' }, 'C', '"_C', { noremap = true, silent = true })

-- Telescope live grep (opens file at matched line)
vim.keymap.set('n', '<leader>sg', function()
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'
  require('telescope').extensions.live_grep_args.live_grep_args {
    additional_args = function() return { '--hidden', '--glob', '!**/.*/**' } end,
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if not entry then return end
        local filename = vim.fn.fnameescape(entry.filename)
        vim.cmd('edit ' .. filename)
        if entry.lnum then
          local col = (entry.col and entry.col > 1) and (entry.col - 1) or 0
          vim.schedule(function()
            local win = vim.api.nvim_get_current_win()
            local line_count = vim.api.nvim_buf_line_count(0)
            local lnum = math.min(entry.lnum, line_count)
            vim.api.nvim_win_set_cursor(win, { lnum, col })
            vim.cmd 'normal! zz'
          end)
        end
      end)
      return true
    end,
  }
end, { desc = 'Live grep (jump to matched line)' })

-- Search and replace
vim.keymap.set(
  'n',
  '<leader>S',
  ':%s/<C-r>///gc<Left><Left><Left>',
  { desc = 'Search and replace' }
)
vim.keymap.set(
  'v',
  '<leader>S',
  ':s/<C-r>///gc<Left><Left><Left>',
  { desc = 'Search and replace' }
)

-- Run current file (filetype-dependent, set in functions.lua)
vim.keymap.set(
  'n',
  '<leader>r',
  function() require('custom.functions').run_current_file() end,
  { desc = 'Run current file' }
)

-- Show cursor horizontal position (byte col, virtual col, line length)
vim.keymap.set('n', '<leader>h', function()
  local col = vim.fn.col '.'
  local vcol = vim.fn.virtcol '.'
  local line = vim.api.nvim_get_current_line()
  local len = #line
  local vlen = vim.fn.strdisplaywidth(line)
  local msg = string.format('col %d/%d  vcol %d/%d', col, len, vcol, vlen)
  vim.notify(msg, vim.log.levels.INFO, { title = 'Cursor position' })
end, { desc = 'Show cursor column position' })

-- Toggle full multi-line diagnostics for ALL lines (vs. just the cursor line)
vim.keymap.set('n', '<leader>dl', function()
  local cfg = vim.diagnostic.config()
  local cursor_only = not (cfg.virtual_lines and cfg.virtual_lines.current_line == false)
  if cursor_only then
    vim.diagnostic.config {
      virtual_lines = vim.tbl_extend('force', type(cfg.virtual_lines) == 'table' and cfg.virtual_lines or {}, { current_line = false }),
      virtual_text = false,
    }
    vim.notify('Diagnostics: full text on all lines', vim.log.levels.INFO)
  else
    vim.diagnostic.config {
      virtual_lines = vim.tbl_extend('force', type(cfg.virtual_lines) == 'table' and cfg.virtual_lines or {}, { current_line = true }),
      virtual_text = vim.tbl_extend('force', type(cfg.virtual_text) == 'table' and cfg.virtual_text or {}, { current_line = false }),
    }
    vim.notify('Diagnostics: full text on cursor line only', vim.log.levels.INFO)
  end
end, { desc = '[D]iagnostic virtual [L]ines toggle' })
