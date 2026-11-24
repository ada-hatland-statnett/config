-- TeamCity scripts can have unresolved imports even when Maven has the sources.
local M = {}
local declarations = vim.treesitter.query.parse(
  'kotlin',
  [[
  (function_declaration (simple_identifier) @name)
  (class_declaration (type_identifier) @name)
  (object_declaration (type_identifier) @name)
  (enum_entry (simple_identifier) @name)
  (type_alias (type_identifier) @name)
  (property_declaration (variable_declaration (simple_identifier) @name))
]]
)

local function lookup(qualified, sources)
  for _, source in ipairs(sources) do
    local tree =
      vim.treesitter.get_string_parser(source.text, 'kotlin'):parse()[1]
    for _, node in declarations:iter_captures(tree:root(), source.text) do
      local name = vim.treesitter.get_node_text(node, source.text)
      if name == qualified:match '[^.]+$' then
        local parent = node:parent():parent()
        while parent and parent:type() ~= 'source_file' do
          if
            parent:type() == 'class_declaration'
            or parent:type() == 'object_declaration'
          then
            for child in parent:iter_children() do
              if child:type() == 'type_identifier' then
                name = vim.treesitter.get_node_text(child, source.text)
                  .. '.'
                  .. name
                break
              end
            end
          elseif parent:type() == 'function_body' then
            break
          end
          parent = parent:parent()
        end
        if
          parent
          and parent:type() == 'source_file'
          and name == source.name
        then
          local row = node:start()
          local decl = node:parent()
          if decl:type() == 'variable_declaration' then decl = decl:parent() end
          local comment = decl:prev_named_sibling()
          local docs = comment
              and vim.treesitter.get_node_text(comment, source.text)
            or ''
          local last = row
          for child in decl:iter_children() do
            if
              child:type() == 'function_value_parameters'
              or child:type() == 'primary_constructor'
            then
              last = child:end_()
            end
          end
          local signature =
            vim.list_slice(vim.split(source.text, '\n'), row + 1, last + 1)
          return source.file, row + 1, signature, docs:match '^/%*%*(.-)%*/$'
        end
      end
    end
  end
end

function M.attach(buf, definitions)
  local root = vim.fs.dirname(vim.api.nvim_buf_get_name(buf))
  local cache = vim.fn.tempname()
  local function action(hover)
    local qualified =
      vim.api.nvim_get_current_line():match '^%s*import%s+([%w_.]+)'
    local fallback = hover and vim.lsp.buf.hover or definitions
    if not qualified or qualified:sub(-1) == '.' then return fallback() end
    local pos = vim.api.nvim_win_get_cursor(0)
    local helper = vim.fn.stdpath 'config'
      .. '/scripts/kotlin-import-sources.py'
    vim.system(
      { 'python3', helper, cache, qualified },
      { cwd = root, text = true },
      vim.schedule_wrap(function(result)
        if
          vim.api.nvim_get_current_buf() ~= buf
          or not vim.deep_equal(vim.api.nvim_win_get_cursor(0), pos)
        then
          return
        end
        if result.code ~= 0 then
          vim.notify(
            'Could not read the Maven classpath: ' .. vim.trim(result.stderr),
            vim.log.levels.WARN
          )
          return fallback()
        end
        local file, row, signature, doc =
          lookup(qualified, vim.json.decode(result.stdout))
        if not file then return fallback() end
        if hover then
          local lines = { '```kotlin' }
          vim.list_extend(lines, signature)
          lines[#lines + 1] = '```'
          if doc then
            vim.list_extend(
              lines,
              vim.split(vim.trim((doc:gsub('\n%s*%* ?', '\n'))), '\n')
            )
          end
          vim.lsp.util.open_floating_preview(
            lines,
            'markdown',
            { focus_id = 'kotlin-import' }
          )
        else
          vim.cmd "normal! m'"
          vim.cmd.edit(vim.fn.fnameescape(file))
          vim.bo.readonly = true
          vim.api.nvim_win_set_cursor(0, { row, 0 })
        end
      end)
    )
  end
  vim.keymap.set(
    'n',
    'grd',
    function() action(false) end,
    { buffer = buf, desc = 'Go to Kotlin definition' }
  )
  vim.keymap.set(
    'n',
    '?',
    function() action(true) end,
    { buffer = buf, desc = 'Show Kotlin documentation' }
  )
end

return M
