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

local PAGE = 10

-- State of the most recent preview, used to build filtered / paged re-runs.
-- { schema = string, table = string, where = string|nil, offset = integer }
local last_preview = nil

-- Calls already executed this session, keyed by "schema.table" (lowercased).
-- Only unfiltered, first-page previews are remembered, so re-previewing a table
-- can re-display the existing result set instead of hitting the database again.
local session_calls = {}

--- @return string
local function preview_key(schema, tbl) return (schema .. '.' .. tbl):lower() end

--- Build the preview query string from the current `last_preview` state.
--- @param fetch_count integer  number of rows to fetch
--- @return string
local function build_query(fetch_count)
  local p = last_preview
  local query = 'SELECT * FROM ' .. p.schema .. '.' .. p.table
  if p.where and p.where ~= '' then query = query .. ' WHERE ' .. p.where end
  query = query .. ' ORDER BY 1'
  query = query .. ' OFFSET ' .. p.offset .. ' ROWS FETCH NEXT ' .. fetch_count .. ' ROWS ONLY'
  return query
end

-- Whether we've registered the persistent retry listener.
local retry_listener_registered = false
-- State for the current retry-aware execution.
local pending_retry = nil -- { call_id, schema, table }

--- Register a one-time listener (persistent, but guarded) that retries with
--- FETCH NEXT 1 when the preview query fails.
local function ensure_retry_listener()
  if retry_listener_registered then return end
  retry_listener_registered = true

  local core = require 'dbee.api.core'
  core.register_event_listener('call_state_changed', function(data)
    local call = data and data.call
    if not call or not pending_retry then return end
    if call.id ~= pending_retry.call_id then return end

    if call.state == 'executing_failed' or call.state == 'retrieving_failed' then
      pending_retry = nil
      -- Retry with a single row to confirm the table is accessible at all.
      vim.schedule(function()
        if not last_preview then return end
        local fallback_query = build_query(1)
        vim.notify('Preview failed, retrying with 1 row...', vim.log.levels.WARN)
        require('dbee').execute(fallback_query)
      end)
    elseif call.state == 'archived' or call.state == 'retrieving' then
      -- success, clear pending
      pending_retry = nil
    end
  end)
end

--- Build and run the preview query from the current `last_preview` state.
local function run_current()
  local p = last_preview
  if not p then return end

  local core = require 'dbee.api.core'
  local conn = core.get_current_connection()
  if not conn then
    require('dbee').execute(build_query(PAGE))
    return
  end

  local query = build_query(PAGE)
  local ui = require 'dbee.api.ui'
  local call = core.connection_execute(conn.id, query)
  ui.result_set_call(call)
  if call and not (p.where and p.where ~= '') and p.offset == 0 then
    session_calls[preview_key(p.schema, p.table)] = call
  end
  require('dbee').open()
end

--- Re-display an already executed call for schema.table, if we have one.
--- @return boolean  true if the cached result was shown
local function show_cached(schema, tbl)
  local key = preview_key(schema, tbl)
  local call = session_calls[key]
  if not call then return false end

  local ok = pcall(function()
    require('dbee.api.ui').result_set_call(call)
    require('dbee').open()
  end)
  if not ok then
    session_calls[key] = nil
    return false
  end

  last_preview = { schema = schema, table = tbl, where = nil, offset = 0 }
  return true
end

--- Start a fresh preview of schema.table (offset 0, no filter).
local function start_preview(schema, tbl)
  last_preview = { schema = schema, table = tbl, where = nil, offset = 0 }
  run_current()
end

--- Jump to the definition of a CTE named `name` in the current buffer.
--- Matches `name AS (` (optionally preceded by `WITH` or a comma).
--- @return boolean  true if a definition was found and the cursor moved
local function jump_to_cte(name)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local needle = name:lower()

  for lnum, line in ipairs(lines) do
    local lower = line:lower()
    local init = 1
    while true do
      local s, e = lower:find(needle, init, true)
      if not s then break end
      -- must be a whole word ...
      local before = s > 1 and lower:sub(s - 1, s - 1) or ''
      local after_ok = not lower:sub(e + 1, e + 1):match '[%w_]'
      if not before:match '[%w_.]' and after_ok then
        -- ... followed by `AS (` (materialization hints allowed)
        local rest = lower:sub(e + 1)
        if rest:match '^%s+as%s*%(' or rest:match '^%s+as%s+n?o?t?%s*materialized%s*%(' then
          vim.cmd "normal! m'" -- keep the jumplist usable with <C-o>
          vim.api.nvim_win_set_cursor(0, { lnum, s - 1 })
          vim.cmd 'normal! zz'
          return true
        end
      end
      init = s + 1
    end
  end
  return false
end

--- Preview the table named by the word under the cursor (in a .sql buffer).
--- If the table was already previewed this session, the existing result set is
--- re-displayed instead of re-running the query. If the name is not a known
--- table, jump to a CTE of that name in the current buffer instead.
function M.preview_under_cursor()
  local word = vim.fn.expand '<cword>'
  if word == '' then
    vim.notify('No word under cursor', vim.log.levels.WARN)
    return
  end

  local schema = require('custom.blink-dbee').get_schema_for_table(word)
  if not schema then
    if jump_to_cte(word) then return end
    vim.notify('Table "' .. word .. '" not found in cache and no CTE by that name. Try <leader>R to refresh.', vim.log.levels.WARN)
    return
  end

  if show_cached(schema, word) then return end

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

--- Forget all previews remembered this session (next `grd` re-queries).
function M.clear_session_cache() session_calls = {} end

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
