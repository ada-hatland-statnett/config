-- Autocommands
-- See `:help lua-guide-autocommands`

-- Highlight when yanking text
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function() vim.hl.on_yank() end,
})

-- Per-repo sessions: saved by `M` (see keymaps), restored on bare `nvim`
vim.opt.sessionoptions = 'buffers,curdir,folds,tabpages,winsize'

local function session_file()
  local root = vim.fs.root(vim.fn.getcwd(), '.git') or vim.fn.getcwd()
  local dir = vim.fn.stdpath 'state' .. '/sessions'
  vim.fn.mkdir(dir, 'p')
  local key = root
  if vim.fs.root(vim.fn.getcwd(), '.git') then
    local out = vim.system({ 'git', 'symbolic-ref', '--short', '-q', 'HEAD' }, { cwd = root, text = true }):wait()
    local branch = vim.trim(out.stdout or '')
    if out.code == 0 and branch ~= '' then key = root .. '@' .. branch end
  end
  return dir .. '/' .. key:gsub('[/\\:]', '%%') .. '.vim'
end

function _G.SaveSession()
  -- Drop special windows/buffers (neo-tree, terminals, etc.) that don't restore well
  pcall(vim.cmd, 'Neotree close')
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buftype ~= '' then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
  end
  vim.cmd('silent! mksession! ' .. vim.fn.fnameescape(session_file()))
end

local active_session
function _G.ClearSession()
  active_session = nil
  os.remove(session_file())
end

-- Once a session is restored, keep its buffer list in sync: opening a file
-- adds it, deleting a buffer (e.g. `<leader>d`) removes it. Neo-tree and
-- terminal windows are skipped by mksession given the sessionoptions above.
local sync_pending = false
local function sync_session()
  if not active_session or sync_pending then return end
  sync_pending = true
  vim.schedule(function()
    sync_pending = false
    if vim.v.exiting ~= vim.NIL then return end
    vim.cmd('silent! mksession! ' .. vim.fn.fnameescape(active_session))
  end)
end
vim.api.nvim_create_autocmd({ 'BufAdd', 'BufDelete', 'BufWipeout' }, {
  desc = 'Keep the restored session in sync with the buffer list',
  callback = function(ev)
    if vim.bo[ev.buf].buftype ~= '' or ev.file == '' then return end
    sync_session()
  end,
})

-- On startup with no file arguments, restore the repo session, else open Neo-tree
vim.api.nvim_create_autocmd('VimEnter', {
  nested = true,
  callback = vim.schedule_wrap(function()
    -- Scheduled so lazy.nvim finishes its VimEnter handling before the session
    -- wipes the initial buffer (otherwise: "Invalid buffer id: 1")
    if vim.fn.argc() == 0 then
      if vim.fn.exists 'g:started_by_firenvim' == 1 then return end
      local file = session_file()
      if vim.fn.filereadable(file) == 1 then
        vim.cmd('silent! source ' .. vim.fn.fnameescape(file))
        -- Drop buffers whose files no longer exist (deleted/renamed since the save)
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          local name = vim.api.nvim_buf_get_name(buf)
          if vim.bo[buf].buftype == '' and name ~= '' and not vim.uv.fs_stat(name) and not vim.bo[buf].modified then
            for _, win in ipairs(vim.fn.win_findbuf(buf)) do
              if #vim.api.nvim_tabpage_list_wins(vim.api.nvim_win_get_tabpage(win)) > 1 then
                pcall(vim.api.nvim_win_close, win, false)
              else
                vim.api.nvim_win_call(win, function() vim.cmd 'enew' end)
              end
            end
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
          end
        end
        active_session = file
        sync_session()
      else
        vim.cmd 'Neotree toggle'
      end
    end
  end),
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

-- Remove the temporary worktree created by the fish `grv` function on exit.
if vim.env.REMOTE_VIEW_WORKTREE and vim.env.REMOTE_VIEW_REPO then
  vim.api.nvim_create_autocmd('VimLeavePre', {
    desc = 'Remove the grv remote-view worktree',
    callback = function()
      local dir, repo = vim.env.REMOTE_VIEW_WORKTREE, vim.env.REMOTE_VIEW_REPO
      -- Leave the worktree first so nothing holds it open.
      pcall(vim.cmd.cd, vim.fn.fnameescape(repo))
      vim.fn.system { 'git', '-C', repo, 'worktree', 'remove', '--force', dir }
      if vim.v.shell_error ~= 0 then
        vim.fn.delete(dir, 'rf')
        vim.fn.system { 'git', '-C', repo, 'worktree', 'prune' }
      end
    end,
  })
end

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
