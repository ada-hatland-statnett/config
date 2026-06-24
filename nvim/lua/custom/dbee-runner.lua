-- SQL runner for nvim-dbee that mimics SQL Developer / DBeaver:
-- runs the whole buffer statement-by-statement and, on the first failure,
-- reports the exact buffer line of the failing statement.
--
-- Backend state machine (from nvim-dbee/dbee/core/call.go):
--   executing -> executing_failed                     (error before results)
--   executing -> retrieving -> retrieving_failed       (error while draining)
--   executing -> retrieving -> archived                (success, terminal)
-- A successful call always reaches `archived`, driven by the backend goroutine
-- independent of the UI, so waiting on it is reliable.

local M = {}

local TERM_FAIL = { executing_failed = true, retrieving_failed = true, archive_failed = true, canceled = true }
local TERM_OK = { archived = true }

-- Safety net: if no terminal event arrives within this window, give up so the
-- runner can never get permanently stuck.
local STATEMENT_TIMEOUT_MS = 120000

--------------------------------------------------------------------------------
-- Statement splitting (semicolon-aware; ignores ; in '...' strings and -- comments)
--------------------------------------------------------------------------------

--- @param lines string[]
--- @return { sql: string, line: integer }[]
local function split_statements(lines)
  local text = table.concat(lines, '\n')

  -- map each byte position to its 1-based buffer line
  local char_line = {}
  do
    local lnum = 1
    for pos = 1, #text do
      char_line[pos] = lnum
      if text:sub(pos, pos) == '\n' then lnum = lnum + 1 end
    end
  end

  -- blank out -- line comments (keep newlines so the line map stays valid)
  do
    local out = {}
    local in_string = false
    local i, len = 1, #text
    while i <= len do
      local ch = text:sub(i, i)
      if in_string then
        out[#out + 1] = ch
        if ch == "'" then
          if text:sub(i + 1, i + 1) == "'" then
            out[#out + 1] = "'"
            i = i + 1
          else
            in_string = false
          end
        end
      else
        if ch == '-' and text:sub(i + 1, i + 1) == '-' then
          local nl = text:find('\n', i, true) or (len + 1)
          for _ = i, nl - 1 do
            out[#out + 1] = ' '
          end
          i = nl - 1
        else
          out[#out + 1] = ch
          if ch == "'" then in_string = true end
        end
      end
      i = i + 1
    end
    text = table.concat(out)
  end

  local statements = {}
  local in_string = false
  local seg_start = 1

  local function push(seg_end)
    local raw = text:sub(seg_start, seg_end)
    local trimmed = vim.trim(raw)
    if trimmed ~= '' then
      local offset = raw:find '%S'
      local start_pos = seg_start + (offset and (offset - 1) or 0)
      statements[#statements + 1] = { sql = trimmed, line = char_line[start_pos] or 1 }
    end
  end

  local i, len = 1, #text
  while i <= len do
    local ch = text:sub(i, i)
    if in_string then
      if ch == "'" then
        if text:sub(i + 1, i + 1) == "'" then
          i = i + 1
        else
          in_string = false
        end
      end
    else
      if ch == "'" then
        in_string = true
      elseif ch == ';' then
        push(i - 1)
        seg_start = i + 1
      end
    end
    i = i + 1
  end
  push(len)

  return statements
end

--------------------------------------------------------------------------------
-- Sequential execution
--------------------------------------------------------------------------------

-- A single persistent listener is registered once (dbee has no unregister API).
local active = nil
local listener_registered = false
local exec_current, dispatch

local function finish_ok(total)
  active = nil
  vim.notify(string.format('Executed %d statement(s) successfully', total), vim.log.levels.INFO)
end

local function finish_fail(stmt, err)
  active = nil
  vim.notify(string.format('SQL error at line %d:\n%s\n\n> %s', stmt.line, err, stmt.sql:gsub('%s+', ' '):sub(1, 120)), vim.log.levels.ERROR)
  pcall(vim.api.nvim_win_set_cursor, 0, { stmt.line, 0 })
end

function exec_current()
  local a = active
  if not a then return end

  if a.idx > #a.statements then
    finish_ok(#a.statements)
    return
  end

  local stmt = a.statements[a.idx]
  local is_last = a.idx == #a.statements
  a.handled = false
  a.token = (a.token or 0) + 1
  local my_token = a.token

  local call = a.core.connection_execute(a.conn_id, stmt.sql)
  if not call or not call.id then
    finish_fail(stmt, 'failed to start execution')
    return
  end
  a.current_call_id = call.id

  -- Show the result panel for the final statement (matches single-run behavior).
  if is_last then pcall(a.ui.result_set_call, call) end

  -- If the call already reached a terminal state synchronously, handle it.
  if call.state and (TERM_FAIL[call.state] or TERM_OK[call.state]) then
    vim.schedule(function()
      if active == a and not a.handled then dispatch(call) end
    end)
  end

  -- Safety timeout in case no terminal event ever arrives.
  vim.defer_fn(function()
    if active == a and not a.handled and a.token == my_token then finish_fail(stmt, 'timed out waiting for result') end
  end, STATEMENT_TIMEOUT_MS)
end

-- `call` is a CallDetails table: { id, state, error, ... }
function dispatch(call)
  local a = active
  if not a or a.handled then return end
  if not call or call.id ~= a.current_call_id then return end

  local stmt = a.statements[a.idx]

  if TERM_FAIL[call.state] then
    a.handled = true
    finish_fail(stmt, call.error or call.state or 'unknown error')
  elseif TERM_OK[call.state] then
    a.handled = true
    a.idx = a.idx + 1
    vim.schedule(exec_current)
  end
end

--- Run the entire buffer, statement by statement, stopping at the first error.
function M.run_buffer()
  local ok = pcall(require, 'dbee')
  if not ok then
    vim.notify('dbee not available', vim.log.levels.ERROR)
    return
  end

  local core = require 'dbee.api.core'
  local ui = require 'dbee.api.ui'

  local conn = core.get_current_connection()
  if not conn then
    vim.notify('No active dbee connection. Open dbee (<leader>p) and select one.', vim.log.levels.WARN)
    return
  end

  local statements = split_statements(vim.api.nvim_buf_get_lines(0, 0, -1, false))
  if #statements == 0 then
    vim.notify('No SQL statements found in buffer', vim.log.levels.WARN)
    return
  end

  if active then
    vim.notify('A SQL run is already in progress', vim.log.levels.WARN)
    return
  end

  require('dbee').open()

  active = {
    core = core,
    ui = ui,
    conn_id = conn.id,
    statements = statements,
    idx = 1,
    handled = false,
    current_call_id = nil,
    token = 0,
  }

  if not listener_registered then
    -- event payload is { call = CallDetails }; unwrap to the call table.
    core.register_event_listener('call_state_changed', function(data) dispatch(data and data.call) end)
    listener_registered = true
  end

  exec_current()
end

--- Run the current visual selection as a single call.
function M.run_selection()
  local ok, dbee = pcall(require, 'dbee')
  if not ok then
    vim.notify('dbee not available', vim.log.levels.ERROR)
    return
  end

  local utils = require 'dbee.utils'
  if not require('dbee.api.core').get_current_connection() then
    vim.notify('No active dbee connection. Open dbee (<leader>p) and select one.', vim.log.levels.WARN)
    return
  end

  local srow, scol, erow, ecol = utils.visual_selection()
  local selection = vim.api.nvim_buf_get_text(0, srow, scol, erow, ecol, {})
  local query = table.concat(selection, '\n')
  if vim.trim(query) == '' then
    vim.notify('Selection is empty', vim.log.levels.WARN)
    return
  end

  dbee.execute(query)
end

return M
