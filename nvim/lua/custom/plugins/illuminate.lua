-- RRethy/vim-illuminate setup
return {
  {
    'RRethy/vim-illuminate',
    event = 'VimEnter',
    config = function()
      require('illuminate').configure {
        providers = { 'lsp', 'treesitter', 'regex' },
        delay = 100,
      }
    end,
  },
}
