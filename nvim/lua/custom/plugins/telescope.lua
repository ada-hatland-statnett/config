-- telescope plugin and extensions configuration
return {
  {
    'nvim-telescope/telescope.nvim',
    enabled = true,
    event = 'VimEnter',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope-live-grep-args.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
        cond = function() return vim.fn.executable 'make' == 1 end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      local previewers = require 'telescope.previewers'
      local image_exts = { png = true, jpg = true, jpeg = true, gif = true, webp = true, avif = true, svg = true }
      local preview_image

      local function clear_preview_image()
        if preview_image then
          preview_image:clear()
          preview_image = nil
        end
      end

      local function buffer_previewer_maker(filepath, bufnr, opts)
        clear_preview_image()
        local ext = vim.fn.fnamemodify(filepath, ':e'):lower()
        local ok, image = pcall(require, 'image')
        if not (image_exts[ext] and ok) then return previewers.buffer_previewer_maker(filepath, bufnr, opts) end

        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
        local winid = opts.winid
        vim.schedule(function()
          if not (vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr) then return end
          preview_image = image.from_file(filepath, { window = winid, buffer = bufnr, x = 0, y = 0, with_virtual_padding = true })
          if preview_image then preview_image:render() end
        end)
      end

      -- Remove the preview image once the Telescope picker closes.
      vim.api.nvim_create_autocmd('WinClosed', {
        group = vim.api.nvim_create_augroup('telescope-image-preview', { clear = true }),
        callback = function()
          vim.schedule(function()
            if preview_image and not vim.api.nvim_win_is_valid(preview_image.window) then clear_preview_image() end
          end)
        end,
      })

      require('telescope').setup {
        defaults = {
          buffer_previewer_maker = buffer_previewer_maker,
        },
        extensions = {
          ['ui-select'] = { require('telescope.themes').get_dropdown() },
          defaults = {
            vimgrep_arguments = {
              '--hidden',
            },
          },
          live_grep_args = {

            auto_quoting = true,
            mappings = {
              i = {
                ['<C-k>'] = require('telescope-live-grep-args.actions').quote_prompt(),
                ['<C-i>'] = require('telescope-live-grep-args.actions').quote_prompt { postfix = ' --iglob ' },
              },
            },
          },
        },
      }
      pcall(require('telescope').load_extension, 'live_grep_args')
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')
      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', function()
        builtin.find_files {
          find_command = { 'rg', '--files', '--hidden', '--glob', '!**/.*/**' },
        }
      end, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set({ 'n', 'v' }, '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader>sc', builtin.commands, { desc = '[S]earch [C]ommands' })
      vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('telescope-lsp-attach', { clear = true }),
        callback = function(event)
          local buf = event.buf
          vim.keymap.set('n', 'grr', builtin.lsp_references, { buffer = buf, desc = '[G]oto [R]eferences' })
          vim.keymap.set('n', 'gri', builtin.lsp_implementations, { buffer = buf, desc = '[G]oto [I]mplementation' })
          -- `grd` is owned by the dbee table preview in SQL buffers, which maps
          -- it buffer-locally on FileType. LspAttach fires afterwards, so just
          -- leave that mapping alone here (deleting it would remove dbee's).
          if vim.bo[buf].filetype ~= 'sql' then
            vim.keymap.set('n', 'grd', builtin.lsp_definitions, { buffer = buf, desc = '[G]oto [D]efinition' })
          end
          vim.keymap.set('n', 'gO', builtin.lsp_document_symbols, { buffer = buf, desc = 'Open Document Symbols' })
          vim.keymap.set('n', 'gW', builtin.lsp_dynamic_workspace_symbols, { buffer = buf, desc = 'Open Workspace Symbols' })
          vim.keymap.set('n', 'grt', builtin.lsp_type_definitions, { buffer = buf, desc = '[G]oto [T]ype Definition' })
        end,
      })
      vim.keymap.set(
        'n',
        '<leader>/',
        function()
          builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
            winblend = 10,
            previewer = false,
          })
        end,
        { desc = '[/] Fuzzily search in current buffer' }
      )
      vim.keymap.set(
        'n',
        '<leader>s/',
        function()
          builtin.live_grep {
            grep_open_files = true,
            prompt_title = 'Live Grep in Open Files',
          }
        end,
        { desc = '[S]earch [/] in Open Files' }
      )
      vim.keymap.set('n', '<leader>sn', function() builtin.find_files { cwd = vim.fn.stdpath 'config' } end, { desc = '[S]earch [N]eovim files' })
    end,
  },
}
