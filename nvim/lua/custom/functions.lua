-- Custom functions

local M = {}

-- Python file runner with terminal split
local _term_bufnr = nil

function M.run_curr_python_file()
  local file_name = vim.api.nvim_buf_get_name(0)

  if file_name == '' then
    vim.notify('No file in current buffer', vim.log.levels.WARN)
    return
  end

  -- If a terminal buffer already exists, close it
  if _term_bufnr and vim.api.nvim_buf_is_valid(_term_bufnr) then
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == _term_bufnr then
        vim.api.nvim_win_close(win, true)
        break
      end
    end
    vim.api.nvim_buf_delete(_term_bufnr, { force = true })
    _term_bufnr = nil
  end

  -- Open a horizontal split below
  vim.cmd 'below 5new'
  _term_bufnr = vim.api.nvim_get_current_buf()

  vim.fn.termopen('python3 ' .. vim.fn.shellescape(file_name), {
    on_exit = function(_, exit_code, _)
      vim.schedule(function()
        if _term_bufnr and vim.api.nvim_buf_is_valid(_term_bufnr) then
          local line_count = vim.api.nvim_buf_line_count(_term_bufnr)
          local new_height = math.min(line_count, 20)

          for _, win in ipairs(vim.api.nvim_list_wins()) do
            if vim.api.nvim_win_get_buf(win) == _term_bufnr then
              if exit_code == 0 then
                vim.api.nvim_win_close(win, true)
              else
                vim.api.nvim_win_set_height(win, new_height)
              end
              break
            end
          end

          if exit_code == 0 then
            vim.api.nvim_buf_delete(_term_bufnr, { force = true })
            _term_bufnr = nil
          end
        end
      end)
    end,
  })

  vim.bo.buflisted = false
  vim.cmd 'wincmd p'
end

-- Dispatch <leader>r based on filetype
function M.run_current_file()
  local ft = vim.bo.filetype
  if ft == 'python' then
    M.run_curr_python_file()
  else
    vim.notify('No runner configured for filetype: ' .. ft, vim.log.levels.WARN)
  end
end

-- Convert print(...) to print(f"{...=}") on current line (Python)
function M.py_print_to_fstring()
  local line = vim.api.nvim_get_current_line()
  local s, e = line:find 'print%('
  if not s then return end
  local depth, i, close = 1, e + 1, nil
  while i <= #line do
    local c = line:sub(i, i)
    if c == '(' then
      depth = depth + 1
    elseif c == ')' then
      depth = depth - 1
      if depth == 0 then
        close = i
        break
      end
    end
    i = i + 1
  end
  if not close then return end
  local inner = line:sub(e + 1, close - 1)
  if inner == '' then return end
  local new_line = line:sub(1, s - 1) .. 'print(f"{' .. inner .. '=}")' .. line:sub(close + 1)
  vim.api.nvim_set_current_line(new_line)
end

return M
