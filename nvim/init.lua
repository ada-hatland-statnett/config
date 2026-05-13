--[[

==================== READ THIS BEFORE CONTINUING ====================
=====================================================================
========                                    .-----.          ========
========         .----------------------.   | === |          ========
========         |.-""""""""""""""""""-.|   |-----|          ========
========         ||                    ||   | === |          ========
========         ||   KICKSTART.NVIM   ||   |-----|          ========
========         ||                    ||   | === |          ========
========         ||                    ||   |-----|          ========
========         ||:Tutor              ||   |:::::|          ========
========         |'-..................-'|   |____o|          ========
========         `"")----------------(""`   ___________      ========
========        /::::::::::|  |::::::::::\  \ no mouse \     ========
========       /:::========|  |==hjkl==:::\  \ required \    ========
========      '""""""""""""'  '""""""""""""'  '""""""""""'   ========
========                                                     ========
=====================================================================
=====================================================================
What is Kickstart?

  Kickstart.nvim is *not* a distribution.

  Kickstart.nvim is a starting point for your own configuration.
    The goal is that you can read every line of code, top-to-bottom, understand
    what your configuration is doing, and modify it to suit your needs.

    Once you've done that, you can start exploring, configuring and tinkering to
    make Neovim your own! That might mean leaving Kickstart just the way it is for a while
    or immediately breaking it into modular pieces. It's up to you!

    If you don't know anything about Lua, I recommend taking some time to read through
    a guide. One possible example which will only take 10-15 minutes:
      - https://learnxinyminutes.com/docs/lua/


    After understanding a bit more about Lua, you can use `:help lua-guide` as a
    reference for how Neovim integrates Lua.
    - :help lua-guide
    - (or HTML version): https://neovim.io/doc/user/lua-guide.html

Kickstart Guide:
  TODO: The very first thing you should do is to run the command `:Tutor` in Neovim.

    If you don't know what this means, type the following:
      - <escape key>
      - :
      - Tutor
      - <enter key>
    (If you already know the Neovim basics, you can skip this step.)
  
  Once you've completed that, you can continue working through **AND READING** the rest
  of the kickstart init.lua.

  Next, run AND READ `:help`.
    This will open up a help window with some basic information
    about reading, navigating and searching the builtin help documentation.

    with something. It's one of my favorite Neovim features.

    MOST IMPORTANTLY, we provide a keymap "<space>sh" to [s]earch the [h]elp documentation,
    which is very useful when you're not exactly sure of what you're looking for.


  I have left several `:help X` comments throughout the init.lua
    These are hints about where to find more information about the relevant settings,
    plugins or Neovim features used in Kickstart.

   NOTE: Look for lines like this

    Throughout the file. These are for you, the reader, to help you understand what is happening.
    Feel free to delete them once you know what you're doing, but they should serve as a guide
    for when you are first encountering a few different constructs in your Neovim config.

If you experience any errors while trying to install kickstart, run `:checkhealth` for more info.

I hope you enjoy your Neovim journey,
- TJ

P.S. You can delete this when you're done too. It's your config now! :)
--]]
-- See `:help mapleader`
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true
-- [[ Setting options ]]
-- See `:help vim.o`
-- NOTE: You can change these options as you wish!
--  For more options, you can see `:help option-list`

-- Make line numbers default
vim.o.number = true
-- You can also add relative line numbers, to help with jumping.
--  Experiment for yourself to see if you like it!
-- vim.o.relativenumber = true

-- Enable mouse mode, can be useful for resizing splits for example!
vim.o.mouse = 'a'

-- Don't show the mode, since it's already in the status line
vim.o.showmode = false
-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.o.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250

-- Decrease mapped sequence wait time
vim.o.timeoutlen = 300

-- Configure how new splits should be opened
vim.o.splitright = true
vim.o.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
--
--  Notice listchars is set using `vim.opt` instead of `vim.o`.
--  It is very similar to `vim.o` but offers an interface for conveniently interacting with tables.
--   See `:help lua-options`
--   and `:help lua-guide-options`
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.o.relativenumber = true
vim.opt.scrolloff = 999
-- Preview substitutions live, as you type!
vim.o.inccommand = 'split'

-- Show which line your cursor is on
vim.o.cursorline = true

-- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
-- instead raise a dialog asking if you wish to save the current file(s)
-- See `:help 'confirm'`
vim.o.confirm = true

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Syntax highlighting
-- 'from' and 'import' keywords
vim.api.nvim_set_hl(0, 'pythonInclude', { fg = '#c678dd', bold = true }) -- purple/bold

-- The module name (e.g. 'os' in 'from os import path')
vim.api.nvim_set_hl(0, '@module.python', { fg = '#e5c07b' }) -- yellow

vim.api.nvim_set_hl(0, 'pythonComment', { fg = '#a0a0a0' })
-- Diagnostic Config & Keymaps
-- See :help vim.diagnostic.Opts
vim.diagnostic.config {
  update_in_insert = false,
  severity_sort = true,
  float = { border = 'rounded', source = 'if_many' },
  underline = { severity = vim.diagnostic.severity.ERROR },

  -- Can switch between these as you prefer
  virtual_text = true, -- Text shows up at the end of the line
  virtual_lines = false, -- Teest shows up underneath the line, with virtual lines

  -- Auto open the float, so you can easily read the errors when jumping with `[d` and `]d`
  jump = { float = true },
}

vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })
vim.keymap.set('n', '?', vim.lsp.buf.hover, { desc = 'Show documentation for word under cursor' })
-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- TIP: Disable arrow keys in normal mode
-- vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
-- vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
-- vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
-- vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-n>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-e>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- Don't let Copilot map <Tab> by default (avoids conflicts)
-- search next/prev on t / T
vim.keymap.set('n', 't', 'n', { noremap = true, silent = true }) -- next match
vim.keymap.set('n', 'T', 'N', { noremap = true, silent = true }) -- previous match

-- Map n -> j (down) and e -> k (up).
vim.keymap.set({ 'n', 'x', 'o' }, 'n', 'j', { remap = true, silent = true })
vim.keymap.set({ 'n', 'x', 'o' }, 'e', 'k', { remap = true, silent = true })

-- paragraph jump on E (next paragraph)
vim.keymap.set({ 'n', 'x', 'o' }, 'N', '}', { remap = true, silent = true })
vim.keymap.set({ 'n', 'x', 'o' }, 'E', '{', { remap = true, silent = true })

-- Custom special movement
vim.keymap.set({ 'n', 'x', 'o' }, 'W', 'b')
vim.keymap.set('n', 'H', '<cmd>bprevious<cr>', { desc = 'Buffer: previous' })
vim.keymap.set('n', 'L', '<cmd>bnext<cr>', { desc = 'Buffer: next' })

-- Shift+S to save
vim.keymap.set({ 'n', 'x' }, 'S', '<cmd>write<cr>', { silent = true, desc = 'Save file' })

-- Shift+M: close all buffers AND exit Neovim
vim.keymap.set('n', 'M', function() vim.cmd 'q' end, { silent = true, desc = 'Quit Neovim' })
vim.keymap.set('n', '<leader>d', '<cmd>bdelete<cr>', { desc = 'Buffer: delete' })
vim.keymap.set('n', 'U', '<C-r>', { noremap = true, silent = true })
vim.keymap.set('n', '<leader>sg', ":lua require('telescope').extensions.live_grep_args.live_grep_args()<CR>")
-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`
--
local _term_bufnr = nil
function run_curr_python_file()
  local file_name = vim.api.nvim_buf_get_name(0)

  if file_name == '' then
    vim.notify('No file in current buffer', vim.log.levels.WARN)
    return
  end

  -- If a terminal buffer already exists, close it
  if _term_bufnr and vim.api.nvim_buf_is_valid(_term_bufnr) then
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == _term_bufnr then
        vim.api.nvim_win_close(win, true)
        break
      end
    end
    vim.api.nvim_buf_delete(_term_bufnr, { force = true })
    _term_bufnr = nil
  end

  -- Open a horizontal split below, 20 lines tall (max cap)
  vim.cmd 'below 5new'

  _term_bufnr = vim.api.nvim_get_current_buf()

  vim.fn.termopen('python3 ' .. vim.fn.shellescape(file_name), {
    on_exit = function(_, exit_code, _)
      vim.schedule(function()
        -- Resize window to fit output, capped at 20
        if _term_bufnr and vim.api.nvim_buf_is_valid(_term_bufnr) then
          local line_count = vim.api.nvim_buf_line_count(_term_bufnr)
          local new_height = math.min(line_count, 20)

          for _, win in ipairs(vim.api.nvim_list_wins()) do
            if vim.api.nvim_win_get_buf(win) == _term_bufnr then
              if exit_code == 0 then
                -- Close on success
                vim.api.nvim_win_close(win, true)
              else
                -- Resize to fit output on failure
                vim.api.nvim_win_set_height(win, new_height)
              end
              break
            end
          end

          if exit_code == 0 then
            vim.api.nvim_buf_delete(_term_bufnr, { force = true })
            _term_bufnr = nil
          end
        end
      end)
    end,
  })

  vim.bo.buflisted = false
  vim.cmd 'wincmd p'
end

vim.keymap.set('n', '<leader>r', run_curr_python_file, { desc = 'Run .py file in terminal split' })

-- Convert first `print(...)` on current line to `print(f"{...=}")` (Python only)
local function py_print_to_fstring()
  local line = vim.api.nvim_get_current_line()
  local s, e = line:find 'print%('
  if not s then return end
  -- Walk forward from after '(' matching nested parens to find the closing ')'
  local depth, i, close = 1, e + 1, nil
  while i <= #line do
    local c = line:sub(i, i)
    if c == '(' then
      depth = depth + 1
    elseif c == ')' then
      depth = depth - 1
      if depth == 0 then
        close = i
        break
      end
    end
    i = i + 1
  end
  if not close then return end
  local inner = line:sub(e + 1, close - 1)
  if inner == '' then return end
  local new_line = line:sub(1, s - 1) .. 'print(f"{' .. inner .. '=}")' .. line:sub(close + 1)
  vim.api.nvim_set_current_line(new_line)
end

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'python',
  callback = function(ev)
    vim.keymap.set('n', '<leader>F', py_print_to_fstring, {
      buffer = ev.buf,
      desc = 'Python: print(x) -> print(f"{x=}")',
    })
  end,
})
vim.keymap.set('n', '<leader>S', ':%s/<C-r>///gc<Left><Left><Left>', { desc = 'Search and replace' })
vim.keymap.set('v', '<leader>S', ':s/<C-r>///gc<Left><Left><Left>', { desc = 'Search and replace' })
-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function() vim.hl.on_yank() end,
})
vim.api.nvim_create_autocmd('VimEnter', {
  callback = function()
    -- argc() is the number of file arguments passed to nvim
    if vim.fn.argc() == 0 then
      -- Optional: avoid opening when reading from stdin (e.g. `echo hi | nvim -`)
      if vim.fn.exists 'g:started_by_firenvim' == 1 then return end

      -- Use whichever command you prefer:
      vim.cmd 'Neotree toggle' -- toggle open
    end
  end,
})

-- [[ Install `lazy.nvim` plugin manager ]]
--    See `:help lazy.nvim.txt` or https://github.com/folke/lazy.nvim for more info
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then error('Error cloning lazy.nvim:\n' .. out) end
end

---@type vim.Option
local rtp = vim.opt.rtp
rtp:prepend(lazypath)

-- [[ Configure and install plugins ]]
--
--  To check the current status of your plugins, run
--    :Lazy
--
--  You can press `?` in this menu for help. Use `:q` to close the window
--
--  To update plugins you can run
--    :Lazy update
--
-- NOTE: Here is where you install your plugins.
require('lazy').setup({
  -- NOTE: Plugins can be added via a link or github org/name. To run setup automatically, use `opts = {}`
  -- NOTE: Plugins can also be configured to run Lua code when they are loaded.
  --
  -- This is often very useful to both group configuration, as well as handle
  -- lazy loading plugins that don't need to be loaded immediately at startup.
  --
  -- For example, in the following configuration, we use:
  --  event = 'VimEnter'
  --
  -- which loads which-key before all the UI elements are loaded. Events can be
  -- normal autocommands events (`:help autocmd-events`).
  --
  -- Then, because we use the `opts` key (recommended), the configuration runs
  -- after the plugin has been loaded as `require(MODULE).setup(opts)`.
  -- NOTE: Next step on your Neovim journey: Add/Configure additional plugins for Kickstart
  --
  --  Here are some example plugins that I've included in the Kickstart repository.
  --  Uncomment any of the lines below to enable them (you will need to restart nvim).
  --
  -- require 'kickstart.plugins.debug',
  -- require 'kickstart.plugins.indent_line',
  -- require 'kickstart.plugins.lint',
  -- require 'kickstart.plugins.autopairs',
  -- require 'kickstart.plugins.neo-tree',

  -- NOTE: The import below can automatically add your own plugins, configuration, etc from `lua/custom/plugins/*.lua`
  --    This is the easiest way to modularize your config.
  --
  --  Uncomment the following line and add your plugins to `lua/custom/plugins/*.lua` to get going.
  { import = 'custom.plugins' },
  --
  -- For additional information with loading, sourcing and examples see `:help lazy.nvim-🔌-plugin-spec`
  -- Or use telescope!
  -- In normal mode type `<space>sh` then write `lazy.nvim-plugin`
  -- you can continue same window with `<space>sr` which resumes last telescope search
}, {
  ui = {
    -- If you are using a Nerd Font: set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
