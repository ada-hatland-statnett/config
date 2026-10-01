-- git-conflict plugin configuration
return {
  {
    'akinsho/git-conflict.nvim',
    version = '*',
    config = function()
      -- Shims for deprecated APIs still used by git-conflict.nvim (unfixed upstream)
      rawset(vim, 'highlight', vim.hl)
      local validate = vim.validate
      local short = {
        b = 'boolean', c = 'callable', f = 'function', n = 'number',
        s = 'string', t = 'table', ['nil'] = 'nil',
      }
      local function expand(tp)
        if type(tp) == 'string' then return short[tp] or tp end
        if type(tp) == 'table' then
          local out = {}
          for i, v in ipairs(tp) do out[i] = short[v] or v end
          return out
        end
        return tp
      end
      vim.validate = function(name, ...)
        if type(name) == 'table' and select('#', ...) == 0 then
          for k, spec in pairs(name) do
            validate(k, spec[1], expand(spec[2]), spec[3])
          end
          return
        end
        return validate(name, ...)
      end

      require('git-conflict').setup {
        default_mappings = {
          ours = '<leader>ao',
          theirs = '<leader>at',
          both = '<leader>ab',
          none = '<leader>a0',
          next = '<leader>an',
          prev = '<leader>ap',
        },
      }
    end,
  },
}
