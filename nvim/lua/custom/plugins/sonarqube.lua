-- sonarqube.nvim - SonarLint language server integration for linting
-- Run `:SonarQubeInstallLsp` once to download the language server + analyzers.
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
    cmd = { 'SonarQubeInstallLsp', 'SonarQubeShowConfig', 'SonarQubeListAllRules' },
    opts = {
      lsp = {
        log_level = 'OFF',
        -- Open the rule description on rules.sonarsource.com instead of
        -- rendering raw HTML in a buffer.
        handlers = {
          ['sonarlint/showRuleDescription'] = function(_, res)
            local spec = string.match(res.key, 'S(%d+)')
            if not (res.languageKey and spec) then return end
            vim.ui.open(string.format('https://rules.sonarsource.com/%s/RSPEC-%s', res.languageKey, spec))
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
    config = function(_, opts) require('sonarqube').setup(opts) end,
  },
}
