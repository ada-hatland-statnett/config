-- Options & settings
-- See `:help vim.o`

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.have_nerd_font = true

vim.o.number = true
vim.o.relativenumber = true
vim.o.mouse = 'a'
vim.o.showmode = false
vim.o.breakindent = true
vim.o.undofile = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.signcolumn = 'yes'
vim.o.updatetime = 250
vim.o.timeoutlen = 300
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.list = true
vim.o.inccommand = 'split'
vim.o.cursorline = true
vim.o.confirm = true

vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.opt.scrolloff = 999

-- Sync clipboard between OS and Neovim
vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)

-- Diagnostic config
local function diagnostic_source(diagnostic)
  local src = diagnostic.source or 'unknown'
  -- Prefer the specific rule/linter code when available (e.g. ruff, sonarqube)
  local code = diagnostic.code
  if code and code ~= '' then src = string.format('%s: %s', src, code) end
  return src
end

vim.diagnostic.config {
  update_in_insert = false,
  severity_sort = true,
  float = { border = 'rounded', source = true },
  underline = { severity = vim.diagnostic.severity.ERROR },
  -- Short, truncated inline text on every line except the cursor line
  virtual_text = {
    current_line = false,
    format = function(diagnostic)
      local msg = diagnostic.message:gsub('%s*\n%s*', ' ')
      if #msg > 80 then msg = msg:sub(1, 79) .. '…' end
      return string.format('%s (from %s)', msg, diagnostic_source(diagnostic))
    end,
  },
  -- Full, wrapped multi-line text for the line the cursor is on
  virtual_lines = {
    current_line = true,
    format = function(diagnostic)
      return string.format('%s (from %s)', diagnostic.message, diagnostic_source(diagnostic))
    end,
  },
  jump = { float = true },
}
