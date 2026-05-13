-- git-conflict plugin configuration
return {
  {
    'akinsho/git-conflict.nvim',
    version = '*',
    config = function()
      require('git-conflict').setup {
        default_mappings = {
          ours = '<leader>ac',
          theirs = '<leader>ai',
          both = '<leader>ab',
          none = '<leader>a0',
          next = '<leader>an',
          prev = 'p',
        },
      }
    end,
  },
}
