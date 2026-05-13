-- Glow plugin configuration
return {
  {
    'ellisonleao/glow.nvim',
    config = true,
    cmd = 'Glow',
    keys = {
      { '<leader>md', '<cmd>Glow<cr>', desc = 'Render [M]arkdown in Glow' },
    },
  },
}
