-- tokyonight colorscheme configuration
return {
  {
    'folke/tokyonight.nvim',
    priority = 1000,
    config = function()
      require('tokyonight').setup {
        styles = {
          comments = { italic = false },
        },
        -- Give more colour to things that are plain white (fg) by default
        on_highlights = function(hl, c)
          -- Variables / identifiers
          hl['@variable'] = { fg = c.fg } -- plain white
          hl['@variable.parameter'] = { fg = c.orange, italic = true }
          hl['@variable.member'] = { fg = c.teal } -- attributes: obj.attr
          hl['@property'] = { fg = c.teal }
          hl['@variable.builtin'] = { fg = c.red, italic = true } -- self, cls
          -- Functions / calls
          hl['@function.call'] = { fg = c.blue }
          hl['@function.method.call'] = { fg = c.blue1 }
          hl['@constructor'] = { fg = c.red }
          -- Types / modules
          hl['@type'] = { fg = c.green1 }
          hl['@module'] = { fg = c.cyan }
          hl['@constant'] = { fg = c.orange, bold = true }
          -- Punctuation / operators
          hl['@punctuation.bracket'] = { fg = c.purple }
          hl['@punctuation.delimiter'] = { fg = c.blue5 }
          hl['@operator'] = { fg = c.blue5 }
          hl['@attribute'] = { fg = c.magenta } -- decorators

          -- LSP semantic tokens (pyright etc.) would otherwise override the above
          hl['@lsp.type.variable'] = { link = '@variable' }
          hl['@lsp.type.parameter'] = { link = '@variable.parameter' }
          hl['@lsp.type.property'] = { link = '@property' }
          hl['@lsp.type.namespace'] = { link = '@module' }
          hl['@lsp.type.class'] = { link = '@type' }
          hl['@lsp.typemod.variable.readonly'] = { link = '@constant' }
          hl['@lsp.typemod.variable.defaultLibrary'] =
            { link = '@variable.builtin' }
        end,
      }
      vim.cmd.colorscheme 'tokyonight-night'
    end,
  },
}
