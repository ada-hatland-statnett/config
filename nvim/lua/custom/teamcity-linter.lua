return {
  cmd = 'bash',
  args = { vim.fn.stdpath 'config' .. '/scripts/teamcity-check.sh' },
  ignore_exitcode = true, -- kotlinc exits nonzero for ordinary source errors.
  stream = 'both',
  parser = function(output)
    local lines = vim.split(output, '\n', { plain = true })
    local diagnostics = {}
    for i, line in ipairs(lines) do
      local row, col, level, message = line:match('settings%.kts:(%d+):(%d+): (%a+): (.+)')
      if row then
        -- kotlinc prints the source line and then a row of carets under the token.
        local width = #((lines[i + 2] or ''):match('^%s*(%^+)') or '^')
        local source = lines[i + 1] or ''
        local start = tonumber(col) - 1
        table.insert(diagnostics, {
          lnum = tonumber(row) - 1,
          col = vim.str_byteindex(source, 'utf-16', start, false),
          end_col = vim.str_byteindex(source, 'utf-16', start + width, false),
          severity = level == 'error' and vim.diagnostic.severity.ERROR or vim.diagnostic.severity.WARN,
          source = 'kotlinc',
          message = message,
        })
      end
    end
    if #diagnostics == 0 and vim.trim(output) ~= '' then
      vim.notify('TeamCity compiler check: ' .. vim.trim(output), vim.log.levels.WARN)
    end
    return diagnostics
  end,
}
