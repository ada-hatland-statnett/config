-- neo-tree config
return {
  {
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    cmd = 'Neotree',
    keys = {
      { '<leader>e', '<cmd>Neotree toggle<cr>', desc = 'Neo-tree: toggle' },
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
      'nvim-tree/nvim-web-devicons',
      'antosha417/nvim-lsp-file-operations',
      'folke/snacks.nvim',
    },
    opts = {
      -- Allow opening files into a terminal window (replacing it) instead of
      -- forcing a new split. Default includes 'terminal', which caused files to
      -- open in a separate split alongside the terminal window.
      open_files_do_not_replace_types = { 'Trouble', 'qf', 'Outline' },
      filesystem = {
        follow_current_file = { enabled = true },
        filtered_items = { hide_gitignored = false },
        window = {
          width = 70,
          mappings = {
            ['<cr>'] = 'open',
            ['o'] = 'open',
            ['l'] = 'open',
            ['s'] = 'open_split',
            ['v'] = 'open_vsplit',
            ['S'] = function(state)
              local node = state.tree:get_node()
              if not node or node.type ~= 'file' then return end
              local bufnr = vim.fn.bufnr(node.path)
              if bufnr == -1 or not vim.api.nvim_buf_is_loaded(bufnr) then
                vim.notify('Not open in a buffer: ' .. node.name, vim.log.levels.INFO)
                return
              end
              vim.api.nvim_buf_call(bufnr, function() vim.cmd 'silent write' end)
              vim.notify('Saved ' .. node.name)
            end,
            ['<space>'] = 'none',
            ['<tab>'] = 'focus_preview',
            ['e'] = 'none',
          },
        },
      },
    },
  },
}
