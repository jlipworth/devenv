-- Cell-range computation and iron.nvim send glue.
-- Range functions are pure and unit-tested; send_* depend on iron at runtime.

local cells = require("jupyter.cells")
local M = {}

-- Line range covering the code of the cell containing `line`, excluding the
-- marker line. Returns nil if the cell has no code.
function M.range_for_cell(bufnr, line)
  line = line or vim.api.nvim_win_get_cursor(0)[1]
  local s, e = cells.current_cell_range(bufnr, line)
  -- If line s is itself a marker, skip it.
  local first = vim.api.nvim_buf_get_lines(bufnr, s - 1, s, false)[1]
  if first and first:match(cells.MARKER) then
    s = s + 1
  end
  if s > e then return nil end
  return { s, e }
end

-- Line range covering everything above the current cell's marker (or start).
function M.range_for_above(bufnr, line)
  line = line or vim.api.nvim_win_get_cursor(0)[1]
  local s = cells.cell_start(bufnr, line)
  if s <= 1 then return nil end
  return { 1, s - 1 }
end

-- Line range covering everything below the current cell.
function M.range_for_below(bufnr, line)
  line = line or vim.api.nvim_win_get_cursor(0)[1]
  local _, e = cells.current_cell_range(bufnr, line)
  local total = vim.api.nvim_buf_line_count(bufnr)
  if e >= total then return nil end
  return { e + 1, total }
end

-- --- Iron send wrappers -----------------------------------------------------

local function send(range)
  if not range then return end
  local lines = vim.api.nvim_buf_get_lines(0, range[1] - 1, range[2], false)
  require("iron.core").send("python", lines)
end

function M.run_cell()           send(M.range_for_cell(0))  end
function M.run_all_above()      send(M.range_for_above(0)) end
function M.run_all_below()      send(M.range_for_below(0)) end

function M.run_cell_and_advance()
  M.run_cell()
  cells.goto_next_cell()
end

function M.send_line()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  send({ line, line })
end

function M.send_file()
  local total = vim.api.nvim_buf_line_count(0)
  send({ 1, total })
end

function M.send_visual()
  local s = vim.fn.line("'<")
  local e = vim.fn.line("'>")
  if s == 0 or e == 0 then return end
  send({ s, e })
end

function M.toggle_repl()
  require("iron.core").toggle_repl("python")
end

function M.focus_repl()
  require("iron.core").focus_on("python")
end

function M.restart_repl()
  require("iron.core").close_repl("python")
  require("iron.core").repl_for("python")
end

-- Interrupt by sending SIGINT (ASCII 0x03) directly to the REPL's terminal
-- job channel. Going through iron.core.send would wrap it in bracketed-paste
-- and produce garbage instead of an interrupt.
function M.interrupt_repl()
  local memory = require("iron.memory")
  local repl = memory.get(0, "python") or memory.get_repl_for("python")
  if not repl or not repl.job then
    vim.notify("jupyter: no python REPL to interrupt", vim.log.levels.WARN)
    return
  end
  vim.fn.chansend(repl.job, string.char(3))
end

return M
