-- Table preview + interactive column filtering for nvim-dbee.
--
-- `preview_under_cursor` / `preview_pick` run `SELECT * FROM schema.table ...`
-- and remember which table was shown. While the cursor is in the dbee result
-- buffer:
--   * `filter_column` reads the column under the cursor (by parsing the
--     rendered header line), prompts for a value, and re-runs filtered with a
--     `WHERE <col> LIKE '<value>'` clause.
--   * `load_next` re-runs the same query advanced by one page (OFFSET) to pull
--     the next batch of rows from the database.

local M = {}

local PAGE = 50

-- State of the most recent preview, used to build filtered / paged re-runs.
-- { schema = string, table = string, where = string|nil, offset = integer }
local last_preview = nil

--- Build and run the preview query from the current `last_preview` state.
local function run_current()
  local p = last_preview
  if not p then return end

  local query = 'SELECT * FROM ' .. p.schema .. '.' .. p.table
  if p.where and p.where ~= '' then query = query .. ' WHERE ' .. p.where end
  -- Deterministic order is required for stable OFFSET paging in Oracle.
  query = query .. ' ORDER BY 1'
  query = query .. ' OFFSET ' .. p.offset .. ' ROWS FETCH NEXT ' .. PAGE .. ' ROWS ONLY'
  require('dbee').execute(query)
end

--- Start a fresh preview of schema.table (offset 0, no filter).
local function start_preview(schema, tbl)
  last_preview = { schema = schema, table = tbl, where = nil, offset = 0 }
  run_current()
end

--- Preview the table named by the word under the cursor (in a .sql buffer).
function M.preview_under_cursor()
  local word = vim.fn.expand '<cword>'
  if word == '' then
    vim.notify('No word under cursor', vim.log.levels.WARN)
    return
  end

  local schema = require('custom.blink-dbee').get_schema_for_table(word)
  if not schema then
    vim.notify('Table "' .. word .. '" not found in cache. Try <leader>R to refresh.', vim.log.levels.WARN)
    return
  end

  start_preview(schema, word)
end

--- Pick a table from the full list and preview it.
--- @param force boolean|nil  if true, re-fetch from DB
function M.preview_pick(force)
  local dbee_cmp = require 'custom.blink-dbee'
  if force then vim.notify('Fetching tables from DB...', vim.log.levels.INFO) end
  local tables = dbee_cmp.list_tables(force)
  if not tables or #tables == 0 then
    vim.notify('No tables found. Is dbee connected?', vim.log.levels.WARN)
    return
  end
  vim.ui.select(tables, { prompt = 'Select table to preview:' }, function(choice)
    if not choice then return end
    -- choice is "schema.table"
    local schema, tbl = choice:match '^([^.]+)%.(.+)$'
    if not schema then
      vim.notify('Could not parse "' .. choice .. '"', vim.log.levels.WARN)
      return
    end
    start_preview(schema, tbl)
  end)
end

--- Fuzzy-find a column across all tables; selecting one previews its table.
--- If `force` is true, always re-fetches from the DB and updates the cache file.
--- Otherwise, uses the persisted file if it exists.
--- @param force boolean|nil
function M.find_column(force)
  local dbee_cmp = require 'custom.blink-dbee'
  if force then vim.notify('Fetching columns from DB...', vim.log.levels.INFO) end
  local entries = dbee_cmp.list_all_columns(force)
  if not entries or #entries == 0 then
    vim.notify('No columns found. Is dbee connected?', vim.log.levels.WARN)
    return
  end

  -- format each entry for display; remember the entry by display string
  local items = {}
  local by_label = {}
  for _, e in ipairs(entries) do
    local label = string.format('%s  →  %s.%s', e.column, e.schema, e.table)
    items[#items + 1] = label
    by_label[label] = e
  end

  vim.ui.select(items, { prompt = 'Find column (previews its table):' }, function(choice)
    if not choice then return end
    local e = by_label[choice]
    if not e then return end
    start_preview(e.schema, e.table)
  end)
end

--- Determine the column name under the cursor in the dbee result buffer.
--- The result is a box-drawing table with columns separated by "│". The first
--- line is the header; the first column is an unnamed row-number column.
--- Matching is done by *display column* (not byte offset) so it stays correct
--- on data rows containing multi-byte characters. Returns the trimmed header
--- text of the segment the cursor is in, or nil.
--- @return string|nil
local function column_under_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local header = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
  if not header or header == '' then return nil end

  local sep = '│' -- box-drawing vertical, 3 bytes in UTF-8

  -- Split the header into segments and compute each segment's display-column
  -- range. The separator itself occupies 1 display cell.
  -- segments[i] = { dstart, dend, text }  (display cols are 1-based, inclusive)
  local segments = {}
  local seg_text = {}
  local seg_disp_start = 1
  local disp = 0 -- display width consumed so far

  local pos = 1
  local hlen = #header
  while pos <= hlen do
    if header:sub(pos, pos + #sep - 1) == sep then
      local text = table.concat(seg_text)
      segments[#segments + 1] = { dstart = seg_disp_start, dend = disp, text = text }
      disp = disp + 1 -- the separator cell
      seg_text = {}
      seg_disp_start = disp + 1
      pos = pos + #sep
    else
      local ch = header:sub(pos, pos)
      seg_text[#seg_text + 1] = ch
      disp = disp + vim.fn.strdisplaywidth(ch)
      pos = pos + 1
    end
  end
  -- trailing segment
  segments[#segments + 1] = { dstart = seg_disp_start, dend = disp, text = table.concat(seg_text) }

  -- cursor display column (1-based)
  local cur_disp = vim.fn.virtcol '.'

  for _, seg in ipairs(segments) do
    if cur_disp >= seg.dstart and cur_disp <= seg.dend then
      local name = vim.trim(seg.text)
      if name == '' then return nil end -- row-number column
      return name
    end
  end
  return nil
end

--- Filter the previewed table by the column under the cursor.
--- Resets paging to the first page.
function M.filter_column()
  if not last_preview then
    vim.notify('No previewed table to filter. Preview one with <leader>t / <leader>T first.', vim.log.levels.WARN)
    return
  end

  local col = column_under_cursor()
  if not col then
    vim.notify('Cursor is not on a data column', vim.log.levels.WARN)
    return
  end

  vim.ui.input({ prompt = 'Filter ' .. col .. " LIKE (e.g. 123%): " }, function(value)
    if not value or value == '' then return end
    -- escape single quotes for SQL
    local escaped = value:gsub("'", "''")
    last_preview.where = col .. " LIKE '" .. escaped .. "'"
    last_preview.offset = 0
    run_current()
  end)
end

--- Load the next page (next 50 rows) of the current preview from the database.
function M.load_next()
  if not last_preview then
    vim.notify('No previewed table. Preview one with <leader>t / <leader>T first.', vim.log.levels.WARN)
    return
  end
  last_preview.offset = last_preview.offset + PAGE
  vim.notify(string.format('Loading rows %d-%d', last_preview.offset + 1, last_preview.offset + PAGE), vim.log.levels.INFO)
  run_current()
end

--- Load the previous page (previous 50 rows). Stops at the first page.
function M.load_prev()
  if not last_preview then
    vim.notify('No previewed table. Preview one with <leader>t / <leader>T first.', vim.log.levels.WARN)
    return
  end
  if last_preview.offset == 0 then
    vim.notify('Already at the first page', vim.log.levels.INFO)
    return
  end
  last_preview.offset = math.max(0, last_preview.offset - PAGE)
  vim.notify(string.format('Loading rows %d-%d', last_preview.offset + 1, last_preview.offset + PAGE), vim.log.levels.INFO)
  run_current()
end

--------------------------------------------------------------------------------
-- Sticky header: pin the column-name row in the window's winbar so it stays
-- visible while scrolling vertically. Horizontal scroll is compensated by
-- slicing the header at the window's left column (w_leftcol).
--------------------------------------------------------------------------------

--- Update the winbar of `win` to show the buffer's header line (line 1),
--- aligned to the current horizontal scroll position.
local function update_sticky_header(win)
  if not vim.api.nvim_win_is_valid(win) then return end
  local buf = vim.api.nvim_win_get_buf(win)
  local header = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
  if not header or header == '' then return end

  -- account for horizontal scroll. The header consists of ASCII text and box
  -- separators (each display width 1), so display columns == character offset.
  local view = vim.api.nvim_win_call(win, function() return vim.fn.winsaveview() end)
  local leftcol = view.leftcol or 0
  if leftcol > 0 then header = vim.fn.strcharpart(header, leftcol) end

  -- escape % for the winbar/statusline format
  local safe = header:gsub('%%', '%%%%')
  pcall(vim.api.nvim_set_option_value, 'winbar', safe, { win = win })
end

--- Enable the sticky header for the current dbee result window.
function M.enable_sticky_header(buf)
  local group = vim.api.nvim_create_augroup('DbeeStickyHeader_' .. buf, { clear = true })
  vim.api.nvim_create_autocmd({ 'WinScrolled', 'CursorMoved', 'BufWinEnter' }, {
    group = group,
    buffer = buf,
    callback = function()
      local win = vim.api.nvim_get_current_win()
      if vim.api.nvim_win_get_buf(win) == buf then update_sticky_header(win) end
    end,
  })
  -- initial paint
  local win = vim.fn.bufwinid(buf)
  if win ~= -1 then update_sticky_header(win) end
end

return M
