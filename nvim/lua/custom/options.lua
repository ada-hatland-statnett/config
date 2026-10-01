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

-- Use fish for :terminal (and :! commands)
local fish = vim.fn.exepath 'fish'
if fish ~= '' then vim.o.shell = fish end

vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.opt.scrolloff = 999

-- Sync clipboard between OS and Neovim
-- On WSL: copy via clip.exe (shows up in Windows clipboard + Win+V history).
-- Input is converted to UTF-16LE so non-ASCII (æøå etc.) survives.
if vim.fn.has 'wsl' == 1 then
  local copy = { 'sh', '-c', 'iconv -f UTF-8 -t UTF-16LE | /mnt/c/Windows/System32/clip.exe' }
  -- Base64 round-trip avoids PowerShell's console encoding mangling UTF-8
  local paste = {
    'sh', '-c',
    [[/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoLogo -NoProfile -c '$c = Get-Clipboard -Raw; if ($c) { [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($c.Replace("`r", ""))) }' | base64 -d]],
  }
  vim.g.clipboard = {
    name = 'WslClipboard',
    copy = { ['+'] = copy, ['*'] = copy },
    paste = { ['+'] = paste, ['*'] = paste },
    cache_enabled = 0,
  }
end
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
  jump = {
    on_jump = function(_, bufnr) vim.diagnostic.open_float { bufnr = bufnr, scope = 'cursor', focus = false } end,
  },
}
