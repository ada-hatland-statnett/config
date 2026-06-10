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

-- Per-connection cache:
-- cache[conn_id] = {
--   structure_items = { <completion items for schemas/tables/views> } | nil,
--   table_lookup = { [lowercase table name] = { name=, schema=, type= } },
--   columns = { [lowercase table name] = { <completion items> } },
--   fetching = { [lowercase table name] = true },  -- in-flight guard
--   structure_fetching = bool,
-- }
local cache = {}

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
    or { structure_items = nil, table_lookup = {}, columns = {}, fetching = {}, structure_fetching = false }
  return cache[conn_id]
end

-- Build structure (schemas/tables/views) items and the table lookup, cached.
local function ensure_structure(conn, api)
  local c = conn_cache(conn.id)
  if c.structure_items or c.structure_fetching then return end
  c.structure_fetching = true

  vim.schedule(function()
    local ok, structures = pcall(api.connection_get_structure, conn.id)
    c.structure_fetching = false
    if not ok or not structures then return end

    local items = {}
    for _, schema_node in ipairs(structures) do
      local schema_name = schema_node.name
      items[#items + 1] = { label = schema_name, kind = Kind.Module, insertText = schema_name, detail = 'schema' }

      for _, obj in ipairs(schema_node.children or {}) do
        local kind, detail = Kind.Struct, (obj.type or 'table')
        local t = (obj.type or ''):lower()
        if t:find 'view' then
          kind = Kind.Interface
          detail = 'view'
        end
        items[#items + 1] = {
          label = obj.name,
          kind = kind,
          insertText = obj.name,
          detail = detail .. ' (' .. schema_name .. ')',
          labelDetails = { description = schema_name },
        }
        c.table_lookup[obj.name:lower()] = { name = obj.name, schema = schema_name, type = obj.type or 'table' }
      end
    end
    c.structure_items = items
  end)
end

-- Fetch & cache columns for a single table (in the background).
local function ensure_columns(conn, api, tbl_key)
  local c = conn_cache(conn.id)
  if c.columns[tbl_key] or c.fetching[tbl_key] then return end
  local meta = c.table_lookup[tbl_key]
  if not meta then return end
  c.fetching[tbl_key] = true

  vim.schedule(function()
    local ok, columns = pcall(api.connection_get_columns, conn.id, {
      table = meta.name,
      schema = meta.schema,
      materialization = meta.type,
    })
    c.fetching[tbl_key] = nil
    if not ok or not columns then return end

    local items = {}
    for _, col in ipairs(columns) do
      items[#items + 1] = {
        label = col.name,
        kind = Kind.Field,
        insertText = col.name,
        detail = (col.type or 'column') .. ' (' .. meta.name .. ')',
        labelDetails = { description = meta.name },
      }
    end
    c.columns[tbl_key] = items
  end)
end

-- Parse table names referenced in the buffer (FROM / JOIN / UPDATE / INTO).
local function referenced_tables()
  local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
  local found = {}
  for keyword, ident in text:gmatch '([%a]+)%s+([%a_][%w_]*)' do
    local k = keyword:lower()
    if k == 'from' or k == 'join' or k == 'update' or k == 'into' then found[ident:lower()] = true end
  end
  return found
end

function dbee_source:get_completions(_, callback)
  local conn, api = get_conn()
  if not conn then
    callback { is_incomplete_forward = false, is_incomplete_backward = false, items = {} }
    return
  end

  local c = conn_cache(conn.id)

  -- Kick off structure fetch if not cached yet (non-blocking).
  ensure_structure(conn, api)

  -- Kick off column fetches for any tables referenced in the buffer (non-blocking).
  for tbl_key in pairs(referenced_tables()) do
    ensure_columns(conn, api, tbl_key)
  end

  -- Assemble whatever we have cached *right now* - never block.
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

  -- Mark incomplete so blink re-queries as background data fills in.
  local still_loading = c.structure_fetching or next(c.fetching) ~= nil or c.structure_items == nil

  callback {
    is_incomplete_forward = still_loading,
    is_incomplete_backward = still_loading,
    items = items,
  }
end

-- Public helper to clear the cache (e.g. after changing connection / schema).
function dbee_source.clear_cache() cache = {} end

-- Look up the schema for a table name from the cache.
-- If the cache is empty, synchronously fetches the structure first.
-- Returns schema string or nil if not found.
function dbee_source.get_schema_for_table(table_name)
  local conn, api = get_conn()
  if not conn then return nil end

  local c = conn_cache(conn.id)

  -- Populate cache synchronously if not yet loaded
  if not c.structure_items then
    local ok, structures = pcall(api.connection_get_structure, conn.id)
    if ok and structures then
      local items = {}
      for _, schema_node in ipairs(structures) do
        local schema_name = schema_node.name
        items[#items + 1] = { label = schema_name, kind = Kind.Module, insertText = schema_name, detail = 'schema' }
        for _, obj in ipairs(schema_node.children or {}) do
          local kind, detail = Kind.Struct, (obj.type or 'table')
          local t = (obj.type or ''):lower()
          if t:find 'view' then
            kind = Kind.Interface
            detail = 'view'
          end
          items[#items + 1] = {
            label = obj.name,
            kind = kind,
            insertText = obj.name,
            detail = detail .. ' (' .. schema_name .. ')',
            labelDetails = { description = schema_name },
          }
          c.table_lookup[obj.name:lower()] = { name = obj.name, schema = schema_name, type = obj.type or 'table' }
        end
      end
      c.structure_items = items
    end
  end

  local meta = c.table_lookup[table_name:lower()]
  return meta and meta.schema or nil
end

-- Return a sorted list of "schema.table" strings for all cached tables.
-- Populates the cache synchronously if empty.
function dbee_source.list_tables()
  local conn, api = get_conn()
  if not conn then return {} end

  -- Ensure cache is populated (reuse get_schema_for_table's logic)
  dbee_source.get_schema_for_table '__force_cache__'

  local c = cache[conn.id]
  if not c or not c.table_lookup then return {} end

  local results = {}
  for _, meta in pairs(c.table_lookup) do
    results[#results + 1] = meta.schema .. '.' .. meta.name
  end
  table.sort(results)
  return results
end

return dbee_source
