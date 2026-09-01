-- Autocommands
-- See `:help lua-guide-autocommands`

-- Highlight when yanking text
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function() vim.hl.on_yank() end,
})

-- On startup with no file arguments, open an empty buffer with Neo-tree toggled open
vim.api.nvim_create_autocmd('VimEnter', {
  callback = function()
    if vim.fn.argc() == 0 then
      if vim.fn.exists 'g:started_by_firenvim' == 1 then return end
      vim.cmd 'Neotree toggle'
    end
  end,
})

-- Follow the terminal shell's working directory (fish emits OSC 7 on each prompt).
-- When you cd / f / z in the terminal, change Neovim's cwd so Neo-tree follows.
-- Also track the active Python virtualenv, reported by fish via a custom OSC
-- 6666 sequence (see config.fish), so we can hand it back to the launching shell.
local active_venv = ''
vim.api.nvim_create_autocmd('TermRequest', {
  desc = "Follow terminal shell's cwd via OSC 7 and track its venv via OSC 6666",
  callback = function(ev)
    local seq = (ev.data and ev.data.sequence) or vim.v.termrequest
    if type(seq) ~= 'string' then return end
    -- Custom OSC 6666 form: ]6666;venv=/path/to/.venv  (empty = deactivated)
    local venv = seq:match '^\027]6666;venv=([^\027\a]*)'
    if venv then
      active_venv = venv
      return
    end
    -- OSC 7 form: ]7;file://HOSTNAME/PATH
    local url = seq:match '^\027]7;file://[^/]*(/[^\027\a]*)'
    if not url then return end
    -- Percent-decode the path
    local dir = url:gsub('%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end)
    if vim.fn.isdirectory(dir) == 1 and dir ~= vim.fn.getcwd() then
      vim.cmd.cd(vim.fn.fnameescape(dir))
      -- Refresh Neo-tree if it's open
      pcall(function() require('neo-tree.sources.manager').dir_changed 'filesystem' end)
    end
  end,
})

-- On exit, write Neovim's cwd to the file named by $NVIM_CWD_FILE so the
-- launching shell can cd into it. Set by the fish wrapper (see config.fish).
vim.api.nvim_create_autocmd('VimLeavePre', {
  desc = 'Write cwd (and active venv) to files so the parent shell can follow',
  callback = function()
    local path = vim.env.NVIM_CWD_FILE
    if path and path ~= '' then pcall(vim.fn.writefile, { vim.fn.getcwd() }, path) end
    local venv_path = vim.env.NVIM_VENV_FILE
    if venv_path and venv_path ~= '' then pcall(vim.fn.writefile, { active_venv }, venv_path) end
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
