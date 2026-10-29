-- Copilot configuration

-- Bumped on every enable/disable so a pending <leader>p auto-disable can't
-- undo a later toggle
local generation = 0
local auth_checked = false

local function set_enabled(enabled)
  generation = generation + 1
  if enabled then auth_checked = false end
  vim.cmd(enabled and 'Copilot enable' or 'Copilot disable')
end

-- Copilot silently returns no suggestions when signed out, so check sign-in
-- (once per enable) when a completion request comes back empty
local function check_auth(client)
  if auth_checked then return end
  auth_checked = true
  client:request('checkStatus', vim.empty_dict(), function(err, result)
    local status = (result and result.status) or (err and err.message)
    if status ~= 'OK' and status ~= 'MaybeOK' then
      local msg = 'Copilot is not authenticated (%s). Run :Copilot setup'
      vim.notify(msg:format(tostring(status)), vim.log.levels.WARN)
    end
  end)
end

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
    config = function()
      -- copilot.vim resets package.loaded._copilot when this script is first
      -- sourced, which would discard the patches below, so source it first
      vim.cmd.runtime 'autoload/copilot/client.vim'
      -- Shim: copilot.vim still calls deprecated client.notify() (unfixed upstream)
      local ok, copilot = pcall(require, '_copilot')
      if ok then
        copilot.did_change_configuration = function(client_id, settings)
          local client = vim.lsp.get_client_by_id(client_id)
          if not client then return end
          client.settings = settings
          return client:notify('workspace/didChangeConfiguration', { settings = settings })
        end

        -- Run check_auth when a completion request returns no suggestions
        local lsp_request = copilot.lsp_request
        copilot.lsp_request = function(client_id, method, params, bufnr)
          local client = vim.lsp.get_client_by_id(client_id)
          if method ~= 'textDocument/inlineCompletion' or not client then
            return lsp_request(client_id, method, params, bufnr)
          end
          if bufnr == vim.NIL then bufnr = nil end
          local _, id
          _, id = client:request(method, params, function(err, result)
            local response = { id = id, error = err, result = result }
            vim.call('copilot#client#LspResponse', client_id, response)
            local items = result and (result.items or result) or {}
            if err or vim.tbl_isempty(items) then check_auth(client) end
          end, bufnr)
          return id
        end
      end
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
          if vim.g.copilot_enabled == 0 then
            set_enabled(true)
            vim.notify('Copilot enabled', vim.log.levels.INFO)
          else
            set_enabled(false)
            vim.notify('Copilot disabled', vim.log.levels.INFO)
          end
        end,
        mode = { 'n', 'i', 'v', 'x', 't' },
        desc = 'Copilot: toggle',
      },
      {
        '<leader>p',
        function()
          set_enabled(true)
          vim.notify('Copilot enabled for 1 minute', vim.log.levels.INFO)
          local gen = generation
          vim.defer_fn(function()
            if gen ~= generation then return end
            set_enabled(false)
            vim.notify('Copilot disabled (1 min elapsed)', vim.log.levels.INFO)
          end, 60 * 1000)
        end,
        mode = 'n',
        desc = 'Copilot: enable for 1 minute',
      },
    },
  },
}
