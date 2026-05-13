-- Copilot configuration
return {
  {
    'github/copilot.vim',
    cmd = 'Copilot',
    event = 'InsertEnter',
    init = function()
      vim.g.copilot_no_tab_map = true
      vim.cmd 'Copilot enable'
      vim.b.copilot_enabled = 1
    end,
    keys = {
      {
        '<leader><tab>',
        'copilot#Accept("<CR>")',
        mode = 'i',
        expr = true,
        replace_keycodes = false,
        silent = true,
        desc = 'Copilot: accept suggestion',
      },
      {
        '<A-c>',
        function()
          if vim.b.copilot_enabled == 0 then
            vim.cmd 'Copilot enable'
            vim.b.copilot_enabled = 1
          else
            vim.cmd 'Copilot disable'
            vim.b.copilot_enabled = 0
          end
        end,
        mode = { 'n', 'i', 'v', 'x', 't' },
        desc = 'Copilot: toggle (buffer)',
      },
    },
  },
}
