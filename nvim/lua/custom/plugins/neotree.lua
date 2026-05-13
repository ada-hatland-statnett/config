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
      filesystem = {
        follow_current_file = { enabled = true },
        filtered_items = { hide_gitignored = false },
        window = {
          mappings = {
            ['<cr>'] = 'open',
            ['o'] = 'open',
            ['l'] = 'open',
            ['s'] = 'open_split',
            ['v'] = 'open_vsplit',
            ['<space>'] = 'none',
            ['<tab>'] = 'focus_preview',
            ['e'] = 'none',
          },
        },
      },
    },
  },
}
