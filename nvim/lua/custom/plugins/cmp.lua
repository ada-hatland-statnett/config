-- blink.cmp (completion) and snippet engine config
return {
  {
    'saghen/blink.cmp',
    event = 'VimEnter',
    version = '1.*',
    dependencies = {
      {
        'L3MON4D3/LuaSnip',
        version = '2.*',
        build = (function()
          if vim.fn.has 'win32' == 1 or vim.fn.executable 'make' == 0 then return end
          return 'make install_jsregexp'
        end)(),
        dependencies = {
          {
            'rafamadriz/friendly-snippets',
            config = function() require('luasnip.loaders.from_vscode').lazy_load() end,
          },
        },
        opts = {},
      },
      'folke/lazydev.nvim',
    },
    opts = {
      keymap = {
        preset = 'none',
        -- Tab selects the first suggestion, then cycles forward. This leaves
        -- <Enter> free to insert a newline even while the menu is open.
        ['<S-Tab>'] = { 'select_prev', 'fallback' },
        ['<Tab>'] = { 'select_next', 'fallback' },
        -- Explicit accept (menu also inserts as you cycle via auto_insert below).
        ['<C-y>'] = { 'select_and_accept', 'fallback' },
        -- Note: <Enter> is intentionally left unmapped so it always inserts a
        -- newline, even with an autocomplete suggestion present.
      },
      appearance = { nerd_font_variant = 'mono' },
      completion = {
        documentation = { auto_show = false, auto_show_delay_ms = 500 },
        -- Nothing is preselected, so the first <Tab> selects suggestion #1.
        -- auto_insert previews/inserts the selected item as you cycle.
        list = { selection = { preselect = false, auto_insert = true } },
      },
      sources = {
        default = { 'lsp', 'path', 'snippets' },
        per_filetype = {
          sql = { 'dbee', 'path', 'snippets', 'buffer' },
        },
        providers = {
          dbee = {
            name = 'Dbee',
            module = 'custom.blink-dbee',
          },
        },
        -- Global de-duplication across ALL sources. blink runs this per source,
        -- but we track ownership per completion context (ctx.id) so identical
        -- labels coming from different sources (or repeated within one source)
        -- only ever show once. Higher-priority sources win a contested label.
        transform_items = (function()
          local priority = { lsp = 5, dbee = 4, snippets = 3, path = 2, buffer = 1 }
          local dedup = { id = nil, owner = {} }
          return function(ctx, items)
            if dedup.id ~= ctx.id then dedup = { id = ctx.id, owner = {} } end
            local seen = {}
            local out = {}
            for _, item in ipairs(items) do
              local key = (item.label or ''):gsub('%s+$', ''):lower()
              if key == '' then
                out[#out + 1] = item
              elseif not seen[key] then
                local sid = item.source_id
                local owner = dedup.owner[key]
                local keep = owner == nil or owner == sid
                if not keep and (priority[sid] or 0) > (priority[owner] or 0) then keep = true end
                if keep then
                  seen[key] = true
                  dedup.owner[key] = sid
                  out[#out + 1] = item
                end
              end
            end
            return out
          end
        end)(),
      },
      snippets = { preset = 'luasnip' },
      fuzzy = { implementation = 'lua' },
      signature = { enabled = true },
    },
  },
}
