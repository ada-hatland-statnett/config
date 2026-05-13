-- kndndrj/nvim-dbee config
return {
  {
    'kndndrj/nvim-dbee',
    dependencies = { 'MunifTanjim/nui.nvim' },
    build = function()
      require('dbee').install()
    end,
    config = function()
      require('dbee').setup(--[[optional config]])
    end,
    keys = {
      { '<leader>p', function() require('dbee').toggle() end, desc = 'Database UI toggle' },
    },
  },
}
