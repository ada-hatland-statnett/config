-- Copilot configuration
return {
  {
    'github/copilot.vim',
    cmd = 'Copilot',
    event = 'InsertEnter',
    init = function()
      vim.g.copilot_no_tab_map = true
      -- Disabled by default
      vim.cmd 'Copilot disable'
      vim.g.copilot_enabled = 0
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
      {
        '<leader>p',
        function()
          vim.cmd 'Copilot enable'
          vim.g.copilot_enabled = 1
          vim.notify('Copilot enabled for 5 minutes', vim.log.levels.INFO)
          vim.defer_fn(function()
            vim.cmd 'Copilot disable'
            vim.g.copilot_enabled = 0
            vim.notify('Copilot disabled (5 min elapsed)', vim.log.levels.INFO)
          end, 5 * 60 * 1000)
        end,
        mode = 'n',
        desc = 'Copilot: enable for 5 minutes',
      },
    },
  },
}
