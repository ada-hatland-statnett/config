-- which-key plugin configuration
return {
  {
    'folke/which-key.nvim',
    event = 'VimEnter',
    opts = {
      delay = 0,
      icons = { mappings = vim.g.have_nerd_font },
      triggers = {
        { '<auto>', mode = 'nxso' },
        { 's', mode = { 'n', 'x' } },
      },
      spec = {
        { 's', group = '[S]urround', mode = { 'n', 'x' } },
        { '<leader>s', group = '[S]earch', mode = { 'n', 'v' } },
        { '<leader>t', group = '[T]oggle' },
        { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
        { '<leader>a', group = '[A]ccept conflict' },
      },
    },
  },
}
