-- blink.cmp source for nvim-dbee
-- Snappy table/column completion from the active dbee connection.
--
-- Design for speed:
--  * Structure (schemas/tables/views) is fetched once per connection and cached.
--  * Columns are fetched lazily, only for tables referenced in the current buffer
--    (parsed from FROM / JOIN / UPDATE / INTO clauses), and cached per table.
--  * get_completions always returns instantly from cache; any missing data is
--    fetched in the background and shows up on the next keystroke.

local Kind = require('blink.cmp.types').CompletionItemKind

--- @class blink.cmp.DbeeSource : blink.cmp.Source
local dbee_source = {}

local REF_SCAN_MAX_LINES = 4000
local REF_SCAN_MAX_BYTES = 512 * 1024

-- Per-connection cache:
-- cache[conn_id] = {
--   structure_items = { <completion items for schemas/tables/views> } | nil,
--   table_lookup = { [lowercase table name] = { name=, schema=, type= } },
--   columns = { [lowercase table name] = { <completion items> } },
--   fetching = { [lowercase table name] = true },  -- in-flight guard
--   structure_fetching = bool,
-- }
local cache = {}
local ref_scan_cache = {}
local prefetch_timer = nil
local referenced_tables
-- Forward declaration: builds the completion cache from the on-disk snapshot
-- (columns.json). Assigned near the bottom once the file paths are defined.
-- This is intentionally the ONLY data path used while editing, because the
-- live dbee API (vim.fn.DbeeConnectionGet*) is a synchronous RPC to the Go
-- backend that blocks Neovim's main loop -- it cannot be made async from Lua.
local ensure_disk_cache
-- Synchronous variant of the disk loader, used by explicit (user-initiated)
-- actions such as table preview where a return value is needed immediately.
local build_disk_cache_now

function dbee_source.new() return setmetatable({}, { __index = dbee_source }) end

function dbee_source:enabled() return vim.bo.filetype == 'sql' end

local function get_conn()
  local ok = pcall(require, 'dbee')
  if not ok then return nil end
  local api = require 'dbee.api.core'
  local conn_ok, conn = pcall(api.get_current_connection)
  if not conn_ok or not conn then return nil end
  return conn, api
end

local function conn_cache(conn_id)
  cache[conn_id] = cache[conn_id]
    or {
      structure_items = nil,
      table_lookup = {},
      columns = {},
      fetching = {},
      structure_fetching = false,
      combined_items = {},
      items_dirty = true,
      disk_loaded = false,
      disk_loading = false,
    }
  return cache[conn_id]
end

local function rebuild_items(c)
  local items = {}
  if c.structure_items then
    for _, it in ipairs(c.structure_items) do
      items[#items + 1] = it
    end
  end
  for _, col_items in pairs(c.columns) do
    for _, it in ipairs(col_items) do
      items[#items + 1] = it
    end
  end
  c.combined_items = items
  c.items_dirty = false
end

-- Build structure (schemas/tables/views) items and the table lookup, cached.
-- NOTE: This no longer calls the DB. It only loads the on-disk snapshot so it
-- never blocks the editor. Use <leader>L / preview commands to refresh the
-- snapshot from the live database.
local function ensure_structure(conn, _api)
  ensure_disk_cache(conn.id)
end

-- Kept for API compatibility with preview code. Columns already come from the
-- on-disk snapshot loaded by ensure_disk_cache, so this is a no-op on the hot
-- path (never hits the blocking DB RPC).
local function ensure_columns(_conn, _api, _tbl_key) end

local function kick_prefetch(bufnr)
  local conn = get_conn()
  if not conn then return end

  -- Load the cached snapshot from disk (background, no DB, no blocking).
  ensure_disk_cache(conn.id)
  -- Refresh the in-buffer table reference scan (also non-blocking / cached).
  referenced_tables(bufnr)
end

local function schedule_prefetch(bufnr, delay_ms)
  if prefetch_timer then
    prefetch_timer:stop()
    prefetch_timer:close()
    prefetch_timer = nil
  end

  prefetch_timer = vim.uv.new_timer()
  if not prefetch_timer then return end

  prefetch_timer:start(delay_ms, 0, function()
    if prefetch_timer then
      prefetch_timer:stop()
      prefetch_timer:close()
      prefetch_timer = nil
    end
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == 'sql' then
        kick_prefetch(bufnr)
      end
    end)
  end)
end

-- Parse table names referenced in the buffer (FROM / JOIN / UPDATE / INTO).
local function parse_referenced_tables(bufnr)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local to_line = math.min(line_count, REF_SCAN_MAX_LINES)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, to_line, false)
  local seen_bytes = 0
  local found = {}

  for _, line in ipairs(lines) do
    seen_bytes = seen_bytes + #line
    if seen_bytes > REF_SCAN_MAX_BYTES then break end
    for keyword, ident in line:gmatch('([%a]+)%s+([%a_][%w_%.]*)') do
      local k = keyword:lower()
      if k == 'from' or k == 'join' or k == 'update' or k == 'into' then
        local table_name = ident:match '([%a_][%w_]*)$'
        if table_name then found[table_name:lower()] = true end
      end
    end
  end

  return found
end

referenced_tables = function(bufnr)
  local tick = vim.api.nvim_buf_get_changedtick(bufnr)
  local state = ref_scan_cache[bufnr]
  if not state then
    state = { tick = -1, tables = {}, scanning = false }
    ref_scan_cache[bufnr] = state
  end

  if state.tick == tick then return state.tables end
  if state.scanning then return state.tables end

  state.scanning = true
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      ref_scan_cache[bufnr] = nil
      return
    end
    state.tables = parse_referenced_tables(bufnr)
    state.tick = vim.api.nvim_buf_get_changedtick(bufnr)
    state.scanning = false
  end)

  return state.tables
end

function dbee_source:get_completions(_, callback)
  local conn, api = get_conn()
  if not conn then
    callback { is_incomplete_forward = false, is_incomplete_backward = false, items = {} }
    return
  end

  local c = conn_cache(conn.id)
  local bufnr = vim.api.nvim_get_current_buf()

  -- Load the on-disk snapshot once (background, no DB call, never blocks).
  ensure_disk_cache(conn.id)
  -- Keep the buffer table-reference scan warm (cached by changedtick).
  referenced_tables(bufnr)

  if c.items_dirty then rebuild_items(c) end

  -- Mark incomplete only while the disk snapshot is still loading, so blink
  -- re-queries once items are ready.
  local ref_state = ref_scan_cache[bufnr]
  local still_loading = c.disk_loading or (ref_state and ref_state.scanning)

  callback {
    is_incomplete_forward = still_loading,
    is_incomplete_backward = still_loading,
    items = c.combined_items,
  }
end

function dbee_source.setup()
  local group = vim.api.nvim_create_augroup('custom-dbee-prefetch', { clear = true })
  vim.api.nvim_create_autocmd({ 'FileType' }, {
    group = group,
    pattern = 'sql',
    callback = function(ev)
      schedule_prefetch(ev.buf, 250)
    end,
  })
  vim.api.nvim_create_autocmd({ 'InsertLeave', 'BufEnter' }, {
    group = group,
    callback = function(ev)
      if vim.bo[ev.buf].filetype == 'sql' then
        schedule_prefetch(ev.buf, 120)
      end
    end,
  })
end

dbee_source.setup()

-- Public helper to clear the table cache and in-memory state.
-- Does NOT clear the persisted columns file (<leader>L handles that).
function dbee_source.clear_cache()
  cache = {}
  os.remove(TABLES_FILE)
end

-- Look up the schema for a table name.
-- Prefers the on-disk snapshot (no DB, no blocking). Only if the snapshot is
-- empty does it fall back to a live (blocking) fetch -- and this function is
-- only ever called from explicit, user-initiated commands, never while typing.
function dbee_source.get_schema_for_table(table_name)
  local conn, api = get_conn()
  if not conn then return nil end

  local c = conn_cache(conn.id)

  -- Sentinel used by the explicit refresh commands: force a live (blocking)
  -- DB fetch to rebuild the snapshot, bypassing the on-disk cache.
  local force_live = table_name == '__force_cache__'

  -- Prefer the cached snapshot (unless forcing a live refresh).
  if not force_live and vim.tbl_isempty(c.table_lookup) then build_disk_cache_now(conn.id) end

  local meta
  if not force_live then
    meta = c.table_lookup[table_name:lower()]
    if meta then return meta.schema end
  end

  -- Live fetch (user-initiated refresh, or snapshot missing this table).
  if force_live or not c.structure_items then
    local ok, structures = pcall(api.connection_get_structure, conn.id)
    if ok and structures then
      local items = {}
      for _, schema_node in ipairs(structures) do
        local schema_name = schema_node.name
        items[#items + 1] = { label = schema_name:lower(), kind = Kind.Module, insertText = schema_name:lower(), detail = 'schema' }
        for _, obj in ipairs(schema_node.children or {}) do
          local kind, detail = Kind.Struct, (obj.type or 'table')
          local t = (obj.type or ''):lower()
          if t:find 'view' then
            kind = Kind.Interface
            detail = 'view'
          end
          items[#items + 1] = {
            label = obj.name:lower(),
            kind = kind,
            insertText = obj.name:lower(),
            detail = detail .. ' (' .. schema_name:lower() .. ')',
            labelDetails = { description = schema_name:lower() },
          }
          c.table_lookup[obj.name:lower()] = { name = obj.name, schema = schema_name, type = obj.type or 'table' }
        end
      end
      c.structure_items = items
      c.items_dirty = true
    end
  end

  meta = c.table_lookup[table_name:lower()]
  return meta and meta.schema or nil
end
local TABLES_FILE = vim.fn.stdpath 'state' .. '/dbee/tables.json'

--- Load the persisted table list from disk.
--- @return string[]|nil
local function load_tables_file()
  local f = io.open(TABLES_FILE, 'r')
  if not f then return nil end
  local raw = f:read '*a'
  f:close()
  if not raw or raw == '' then return nil end
  local ok, data = pcall(vim.fn.json_decode, raw)
  if ok and type(data) == 'table' then return data end
  return nil
end

--- Save the table list to disk.
--- @param tables string[]
local function save_tables_file(tables)
  local dir = vim.fn.fnamemodify(TABLES_FILE, ':h')
  vim.fn.mkdir(dir, 'p')
  local f = io.open(TABLES_FILE, 'w')
  if not f then return end
  f:write(vim.fn.json_encode(tables))
  f:close()
end

-- Fetch the table list from the DB and save to disk.
function dbee_source.fetch_tables()
  local conn, api = get_conn()
  if not conn then return {} end

  dbee_source.get_schema_for_table '__force_cache__'

  local c = cache[conn.id]
  if not c or not c.table_lookup then return {} end

  local results = {}
  for _, meta in pairs(c.table_lookup) do
    results[#results + 1] = meta.schema .. '.' .. meta.name
  end
  table.sort(results)
  save_tables_file(results)
  return results
end

-- Return a sorted list of "schema.table" strings.
-- If `force` is true, always re-fetches from the DB.
-- Otherwise, uses the persisted file if it exists.
function dbee_source.list_tables(force)
  if not force then
    local from_file = load_tables_file()
    if from_file and #from_file > 0 then return from_file end
  end

  return dbee_source.fetch_tables()
end

-- Persistence path for the column index (survives reloads).
local COLUMNS_FILE = vim.fn.stdpath 'state' .. '/dbee/columns.json'

--- Load the persisted column index from disk.
--- @return { column: string, schema: string, table: string }[]|nil
local function load_columns_file()
  local f = io.open(COLUMNS_FILE, 'r')
  if not f then return nil end
  local raw = f:read '*a'
  f:close()
  if not raw or raw == '' then return nil end
  local ok, data = pcall(vim.fn.json_decode, raw)
  if ok and type(data) == 'table' then return data end
  return nil
end

--- Save the column index to disk.
--- @param entries { column: string, schema: string, table: string }[]
local function save_columns_file(entries)
  local dir = vim.fn.fnamemodify(COLUMNS_FILE, ':h')
  vim.fn.mkdir(dir, 'p')
  local f = io.open(COLUMNS_FILE, 'w')
  if not f then return end
  f:write(vim.fn.json_encode(entries))
  f:close()
end

-- Build a flat index of every column across all tables by querying the DB.
-- Saves the result to disk for persistence.
-- Returns a list of entries: { column = string, schema = string, table = string }
function dbee_source.fetch_all_columns()
  local conn, api = get_conn()
  if not conn then return {} end

  -- ensure table_lookup is populated
  dbee_source.get_schema_for_table '__force_cache__'

  local c = cache[conn.id]
  if not c or not c.table_lookup then return {} end

  c.column_names = c.column_names or {}

  local entries = {}
  for tbl_key, meta in pairs(c.table_lookup) do
    local ok, columns = pcall(api.connection_get_columns, conn.id, {
      table = meta.name,
      schema = meta.schema,
      materialization = meta.type,
    })
    local names = {}
    if ok and columns then
      for _, col in ipairs(columns) do
        names[#names + 1] = col.name
      end
    end
    c.column_names[tbl_key] = names
    for _, col in ipairs(names) do
      entries[#entries + 1] = { column = col, schema = meta.schema, table = meta.name }
    end
  end

  table.sort(entries, function(a, b)
    if a.column:lower() == b.column:lower() then return a.table:lower() < b.table:lower() end
    return a.column:lower() < b.column:lower()
  end)

  save_columns_file(entries)
  return entries
end

-- Return the column index. If `force` is true, always re-fetch from the DB.
-- Otherwise, try the persisted file first, then in-memory cache, then fetch.
function dbee_source.list_all_columns(force)
  if not force then
    -- try persisted file
    local from_file = load_columns_file()
    if from_file and #from_file > 0 then return from_file end
  end

  return dbee_source.fetch_all_columns()
end

-- Build the in-memory completion cache from the on-disk snapshot (columns.json,
-- with tables.json as a supplement). Pure file IO + Lua, NO database RPC, so it
-- never blocks on the network. `c` is the per-connection cache table.
local function populate_from_disk(c)
  local column_entries = load_columns_file() or {}
  local table_entries = load_tables_file() or {}

  local schemas = {}
  local tables = {}
  local items = {}

  -- Tables from tables.json ("schema.table") ensure tables show up even if a
  -- table has no columns recorded.
  for _, qualified in ipairs(table_entries) do
    local schema, tbl = qualified:match '^(.-)%.(.+)$'
    if schema and tbl then
      schemas[schema:lower()] = schema
      local key = tbl:lower()
      if not tables[key] then
        tables[key] = true
        c.table_lookup[key] = { name = tbl, schema = schema, type = 'table' }
        items[#items + 1] = {
          label = tbl:lower(),
          kind = Kind.Struct,
          insertText = tbl:lower(),
          detail = 'table (' .. schema:lower() .. ')',
          labelDetails = { description = schema:lower() },
        }
      end
    end
  end

  -- Columns (and any tables/schemas only present in columns.json).
  for _, e in ipairs(column_entries) do
    if e.schema then schemas[e.schema:lower()] = e.schema end
    if e.table and not tables[e.table:lower()] then
      local key = e.table:lower()
      tables[key] = true
      c.table_lookup[key] = { name = e.table, schema = e.schema, type = 'table' }
      items[#items + 1] = {
        label = e.table:lower(),
        kind = Kind.Struct,
        insertText = e.table:lower(),
        detail = 'table (' .. (e.schema or ''):lower() .. ')',
        labelDetails = { description = (e.schema or ''):lower() },
      }
    end
    if e.column then
      items[#items + 1] = {
        label = e.column:lower(),
        kind = Kind.Field,
        insertText = e.column:lower(),
        detail = 'column (' .. (e.table or ''):lower() .. ')',
        labelDetails = { description = (e.table or ''):lower() },
      }
    end
  end

  -- Schema items.
  for _, schema in pairs(schemas) do
    items[#items + 1] = { label = schema:lower(), kind = Kind.Module, insertText = schema:lower(), detail = 'schema' }
  end

  c.structure_items = items
  c.combined_items = items
  c.items_dirty = false
  c.disk_loaded = true
end

-- Async (non-blocking) disk load: kicks off a scheduled build once per
-- connection. Returns immediately; completion picks up items on the next query.
ensure_disk_cache = function(conn_id)
  local c = conn_cache(conn_id)
  if c.disk_loaded or c.disk_loading then return end
  c.disk_loading = true
  vim.schedule(function()
    local ok = pcall(populate_from_disk, c)
    c.disk_loading = false
    if not ok then c.disk_loaded = false end
  end)
end

-- Synchronous disk load for explicit, user-initiated commands.
build_disk_cache_now = function(conn_id)
  local c = conn_cache(conn_id)
  if c.disk_loaded then return end
  pcall(populate_from_disk, c)
end

return dbee_source
