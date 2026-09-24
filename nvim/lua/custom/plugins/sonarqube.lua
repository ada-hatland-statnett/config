-- sonarqube.nvim - SonarLint language server integration for linting
-- Run `:SonarQubeInstallLsp` once to download the language server + analyzers.
--
-- Connected mode against https://sonar.elhub.cloud is wired up manually below.
-- The plugin has no `connectedMode` option, but sonarlint-ls does support it:
--   * SettingsManager reads sonarlint.connectedMode.connections.sonarqube[] and
--     sonarlint.connectedMode.project
--   * SonarLintExtendedLanguageClient exposes getTokenForServer(String)
-- Both are reachable because `sonarqube.lsp.server` reads `handlers`/`settings`
-- lazily, at client-start time in its FileType autocmd. So registering handlers
-- and extending settings *after* `setup()` still takes effect.
--
-- Requires SONARQUBE_TOKEN_USER in the environment (a *user* token, generated
-- at https://sonar.elhub.cloud/account/security). A project-analysis token is
-- not enough: it cannot read the quality profile, so you silently fall back to
-- the built-in ruleset.

local SERVER_URL = 'https://sonar.elhub.cloud'
local CONNECTION_ID = 'elhub'

-- Fallback binding for repos that ship neither .sonarlint/connectedMode.json
-- nor sonar-project.properties: everything under the watson workspace shares
-- the insight project, since none of those repos has a project of its own.
-- Run `:SonarQubeProjects` to list the real keys from the server.
local INSIGHT_KEY = 'no.elhub.insight.analytics-insight'
local WATSON_DIR = vim.fs.normalize '~/git/watson'

local function git_root()
  local dir = vim.fs.dirname(
    vim.fs.find('.git', { upward = true, path = vim.fn.getcwd() })[1]
  )
  return dir or vim.fn.getcwd()
end

--- Resolve the projectKey for a repo, in order of trustworthiness.
--- Returns nil when unknown, which leaves the server in standalone mode.
local function resolve_project_key(root)
  -- 1. SonarLint's own shared-binding file, if the repo commits one.
  local shared = root .. '/.sonarlint/connectedMode.json'
  if vim.uv.fs_stat(shared) then
    local ok, decoded =
      pcall(vim.json.decode, table.concat(vim.fn.readfile(shared), '\n'))
    if ok and type(decoded) == 'table' and decoded.projectKey then
      return decoded.projectKey
    end
  end

  -- 2. Scanner properties.
  local props = root .. '/sonar-project.properties'
  if vim.uv.fs_stat(props) then
    for _, line in ipairs(vim.fn.readfile(props)) do
      local key = line:match '^%s*sonar%.projectKey%s*=%s*(.-)%s*$'
      if key and key ~= '' then return key end
    end
  end

  -- 3. Anything inside the watson workspace binds to the insight project.
  -- Compare with a trailing slash so a sibling like `watson-toolbox` sitting
  -- next to `watson/` can't match on the prefix alone.
  local normalised = vim.fs.normalize(root)
  if
    normalised == WATSON_DIR
    or vim.startswith(normalised, WATSON_DIR .. '/')
  then
    return INSIGHT_KEY
  end

  return nil
end

return {
  {
    'iamkarasik/sonarqube.nvim',
    -- Must match the filetypes the enabled analyzers register below; the
    -- plugin attaches via a FileType autocmd, so it has to be loaded by then.
    ft = {
      'python',
      'javascript',
      'javascriptreact',
      'javascript.jsx',
      'typescript',
      'typescriptreact',
      'typescript.tsx',
      'html',
      'templ',
      'dockerfile',
      'hcl',
      'terraform',
      'terraform-vars',
      'yaml',
      'json',
      'text',
      'plaintex',
      'tex',
      'xml',
      'xsd',
      'xsl',
      'xslt',
      'svg',
    },
    cmd = {
      'SonarQubeInstallLsp',
      'SonarQubeShowConfig',
      'SonarQubeListAllRules',
      'SonarQubeProjects',
    },
    opts = {
      lsp = {
        log_level = 'OFF',
        -- Open the rule description on rules.sonarsource.com instead of
        -- rendering raw HTML in a buffer.
        handlers = {
          ['sonarlint/showRuleDescription'] = function(_, res)
            local spec = string.match(res.key, 'S(%d+)')
            if not (res.languageKey and spec) then return end
            vim.ui.open(
              string.format(
                'https://rules.sonarsource.com/%s/RSPEC-%s',
                res.languageKey,
                spec
              )
            )
          end,
        },
      },
      rules = { enabled = true },
      python = { enabled = true },
      javascript = { enabled = true, clientNodePath = vim.fn.exepath 'node' },
      html = { enabled = true },
      iac = { enabled = true },
      text = { enabled = true },
      xml = { enabled = true },
    },
    config = function(_, opts)
      require('sonarqube').setup(opts)

      local server = require 'sonarqube.lsp.server'
      -- Connected mode needs a *user* token: project-analysis tokens only
      -- authorise the scanner API, so the server accepts them for analysis but
      -- refuses the endpoints that hand back the quality profile / rule set.
      local token = vim.env.SONARQUBE_TOKEN_USER
        or vim.env.SONARQUBE_TOKEN
        or vim.env.SONARQUBE_TOKEN_PROJECT

      -- The server re-asks for credentials per folder/connection, so an
      -- unguarded notify here fires repeatedly and each one triggers its own
      -- hit-enter prompt. Warn at most once, and off the LSP callback so the
      -- message lands in :messages instead of blocking startup.
      local warned = {}
      local function warn_once(key, msg, level)
        if warned[key] then return end
        warned[key] = true
        vim.schedule(function() vim.notify(msg, level) end)
      end

      -- Server asks for credentials on demand; one connection, so the
      -- serverUrl/connectionId argument needs no disambiguation.
      -- These are server->client *requests*: nvim's rpc dispatcher rejects a
      -- bare `nil` return ("either a result or an error must be sent"), so an
      -- absent value has to be spelled `vim.NIL` to serialise as JSON null.
      server.register_handler('sonarlint/getTokenForServer', function()
        if not token or token == '' then
          warn_once(
            'missing-token',
            'SonarQube: SONARQUBE_TOKEN_USER unset, connected mode disabled',
            vim.log.levels.WARN
          )
          return vim.NIL
        end
        return token
      end)

      -- Handing back a null token makes the server report the credentials as
      -- invalid, which would immediately paper over the more useful "token
      -- unset" warning. Only surface a rejection when there was one to reject.
      server.register_handler('sonarlint/notifyInvalidToken', function()
        if not token or token == '' then return end
        warn_once(
          'invalid-token',
          'SonarQube: token rejected by ' .. SERVER_URL,
          vim.log.levels.ERROR
        )
      end)

      -- Taint vulnerabilities are computed server-side and pushed separately
      -- from normal diagnostics, so they need their own namespace to show up.
      local function publisher(name)
        local ns = vim.api.nvim_create_namespace('sonarqube/' .. name)
        return function(_, params)
          if not params or not params.uri then return end
          local bufnr = vim.uri_to_bufnr(params.uri)
          if not vim.api.nvim_buf_is_loaded(bufnr) then return end
          vim.diagnostic.set(
            ns,
            bufnr,
            vim.lsp.diagnostic.from(params.diagnostics or {})
          )
        end
      end
      server.register_handler(
        'sonarlint/publishTaintVulnerabilities',
        publisher 'taint'
      )
      server.register_handler(
        'sonarlint/publishSecurityHotspots',
        publisher 'hotspots'
      )
      server.register_handler(
        'sonarlint/publishDependencyRisks',
        publisher 'dependency-risks'
      )

      -- Silence the connected-mode chatter the plugin never registered.
      for _, method in ipairs {
        'sonarlint/suggestBinding',
        'sonarlint/suggestConnection',
        'sonarlint/settingsApplied',
        'sonarlint/submitNewCodeDefinition',
        'sonarlint/startProgressNotification',
        'sonarlint/endProgressNotification',
        'sonarlint/reportConnectionCheckResult',
        'sonarlint/maybeShowWiderLanguageSupportNotification',
        'sonarlint/showSoonUnsupportedVersionMessage',
        'sonarlint/didChangePluginStatuses',
        'sonarlint/setReferenceBranchNameForFolder',
      } do
        server.register_handler(method, function() return vim.NIL end)
      end
      server.register_handler(
        'sonarlint/hasJoinedIdeLabs',
        function() return false end
      )
      server.register_handler(
        'sonarlint/askSslCertificateConfirmation',
        function() return false end
      )

      local root = git_root()
      local project_key = resolve_project_key(root)

      -- Deep-extend rather than assign: `rules.setup()` has already populated
      -- sonarlint.rules in this table and we must not clobber it.
      server.settings = vim.tbl_deep_extend('force', server.settings, {
        sonarlint = {
          connectedMode = {
            connections = {
              sonarqube = {
                {
                  connectionId = CONNECTION_ID,
                  serverUrl = SERVER_URL,
                  disableNotifications = true,
                },
              },
            },
            -- Nil projectKey means unbound: analysis still runs, but with the
            -- built-in ruleset instead of the server quality profile.
            project = project_key
                and { connectionId = CONNECTION_ID, projectKey = project_key }
              or nil,
          },
        },
      })

      -- Bind server-side issue matching to the branch actually checked out.
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup(
          'custom-sonarqube',
          { clear = true }
        ),
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client or client.name ~= 'sonarqube' then return end
          local branch = vim.trim(
            vim.fn.system { 'git', '-C', root, 'branch', '--show-current' }
          )
          if vim.v.shell_error == 0 and branch ~= '' then
            client:notify('sonarlint/didLocalBranchNameChange', {
              folderUri = vim.uri_from_fname(root),
              branchName = branch,
            })
          end
        end,
      })

      -- Discovery helper: ask the server for the real project keys, since none
      -- of the elhub repos commit a binding file.
      vim.api.nvim_create_user_command('SonarQubeProjects', function()
        local client = vim.lsp.get_clients({ name = 'sonarqube' })[1]
        if not client then
          vim.notify('SonarQube: LSP is not running', vim.log.levels.ERROR)
          return
        end
        client:request(
          'sonarlint/getRemoteProjectsForConnection',
          { connectionId = CONNECTION_ID },
          function(err, res)
            if err or not res then
              vim.notify(
                'SonarQube: failed to list projects: ' .. vim.inspect(err),
                vim.log.levels.ERROR
              )
              return
            end
            local lines = {}
            for key, name in pairs(res) do
              table.insert(lines, string.format('%s  -- %s', key, name))
            end
            table.sort(lines)
            local buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
            vim.api.nvim_set_option_value('filetype', 'lua', { buf = buf })
            vim.api.nvim_win_set_buf(
              require('sonarqube.util').create_win(buf),
              buf
            )
          end
        )
      end, { desc = 'List SonarQube projects available on ' .. SERVER_URL })

      vim.api.nvim_create_user_command(
        'SonarQubeBinding',
        function()
          vim.notify(
            string.format(
              'root: %s\nprojectKey: %s\ntoken: %s',
              root,
              project_key or '<unbound>',
              token and 'set' or 'MISSING'
            ),
            vim.log.levels.INFO
          )
        end,
        { desc = 'Show the resolved SonarQube connected-mode binding' }
      )
    end,
  },
}
