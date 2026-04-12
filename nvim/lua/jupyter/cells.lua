-- Pure helpers for # %% cell boundaries. No side effects; every function
-- takes bufnr/line arguments explicitly so the module is unit-testable.
local M = {}

-- Lua pattern. `%%` matches one literal `%`, so `%%%%` matches `%%`.
-- A line like `# %` (single percent) is NOT a cell marker and must not match.
M.MARKER = "^# %%%%"

-- Return the Lua pattern-matched marker start line at or above `line`.
-- If no marker is found, returns 1 (implicit first cell).
function M.cell_start(bufnr, line)
  for i = line, 1, -1 do
    local l = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
    if l and l:match(M.MARKER) then
      return i
    end
  end
  return 1
end

-- Return the last line of the cell that contains `line`.
-- If no subsequent marker exists, returns the final line of the buffer.
function M.cell_end(bufnr, line)
  local total = vim.api.nvim_buf_line_count(bufnr)
  for i = line + 1, total do
    local l = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
    if l and l:match(M.MARKER) then
      return i - 1
    end
  end
  return total
end

-- Return (start, end) line numbers for the cell containing `line`.
-- Uses current cursor line if `line` is nil.
function M.current_cell_range(bufnr, line)
  line = line or vim.api.nvim_win_get_cursor(0)[1]
  return M.cell_start(bufnr, line), M.cell_end(bufnr, line)
end

-- Find the next marker line strictly after `line`, or nil.
function M.find_next_marker(bufnr, line)
  local total = vim.api.nvim_buf_line_count(bufnr)
  for i = line + 1, total do
    local l = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
    if l and l:match(M.MARKER) then
      return i
    end
  end
  return nil
end

-- Find the previous marker line strictly before `line`, or nil.
function M.find_prev_marker(bufnr, line)
  for i = line - 1, 1, -1 do
    local l = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
    if l and l:match(M.MARKER) then
      return i
    end
  end
  return nil
end

-- Convenience: move cursor to next marker (no-op at end).
function M.goto_next_cell()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local target = M.find_next_marker(0, line)
  if target then
    vim.api.nvim_win_set_cursor(0, { target, 0 })
  end
end

-- Convenience: move cursor to previous marker (no-op at start).
function M.goto_prev_cell()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local target = M.find_prev_marker(0, line)
  if target then
    vim.api.nvim_win_set_cursor(0, { target, 0 })
  end
end

-- First marker in the buffer, or line 1 if none exist.
function M.goto_first_cell()
  local target = M.find_next_marker(0, 0) or 1
  vim.api.nvim_win_set_cursor(0, { target, 0 })
end

-- Last marker in the buffer, or final line if none exist.
function M.goto_last_cell()
  local total = vim.api.nvim_buf_line_count(0)
  local target = M.find_prev_marker(0, total + 1) or total
  vim.api.nvim_win_set_cursor(0, { target, 0 })
end

return M
