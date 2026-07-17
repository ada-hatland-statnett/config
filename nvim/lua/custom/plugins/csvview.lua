-- csvview.nvim configuration
return {
  {
    'hat0uma/csvview.nvim',
    opts = {
      parser = { comments = { '#', '//' } },
      keymaps = {
        textobject_field_inner = { 'if', mode = { 'o', 'x' } },
        textobject_field_outer = { 'af', mode = { 'o', 'x' } },
        jump_next_field_end = { '<Tab>', mode = { 'n', 'v' } },
        jump_prev_field_end = { '<S-Tab>', mode = { 'n', 'v' } },
        jump_next_row = { '<Enter>', mode = { 'n', 'v' } },
        jump_prev_row = { '<S-Enter>', mode = { 'n', 'v' } },
      },
    },
    cmd = { 'CsvViewEnable', 'CsvViewDisable', 'CsvViewToggle' },
    init = function()
      -- Failsafe: the synchronous delimiter/quote/header detection in
      -- csvview.enable() scans the entire buffer before any async work runs,
      -- so on very large files it blocks the UI and hangs nvim. A timer can't
      -- interrupt synchronous code, so the reliable guard is to check size
      -- *before* enabling. We gate on both line count and raw byte size.
      local MAX_LINES = 200000
      local MAX_BYTES = 50 * 1024 * 1024 -- 50 MB

      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'csv',
        callback = function(args)
          local bufnr = args.buf
          local line_count = vim.api.nvim_buf_line_count(bufnr)

          local too_big, reason
          if line_count > MAX_LINES then
            too_big = true
            reason = string.format('%d lines > %d', line_count, MAX_LINES)
          else
            local name = vim.api.nvim_buf_get_name(bufnr)
            local ok, stat = pcall(vim.uv.fs_stat, name)
            if ok and stat and stat.size > MAX_BYTES then
              too_big = true
              reason = string.format('%.1f MB > %d MB', stat.size / 1024 / 1024, MAX_BYTES / 1024 / 1024)
            end
          end

          if too_big then
            vim.notify(
              'csvview: auto-enable skipped (' .. reason .. '). Run :CsvViewEnable to force.',
              vim.log.levels.WARN
            )
            return
          end

          vim.cmd 'CsvViewEnable'
        end,
      })
    end,
  },
}
