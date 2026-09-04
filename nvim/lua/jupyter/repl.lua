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
  -- The '< and '> marks are only written when visual mode is left. The keymap
  -- is an x-mode Lua callback, so we are still in visual mode here and reading
  -- the marks now would send the *previous* selection. Leave visual mode first
  -- ("x" flushes the typeahead synchronously) so the marks describe the
  -- selection the user just made.
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
  end
  local s = vim.fn.line("'<")
  local e = vim.fn.line("'>")
  if s == 0 or e == 0 then return end
  send({ s, e })
end

-- Metadata for the python REPL, or nil if iron has never started one.
-- The pinned iron.nvim keeps REPL metadata in `iron.state`; `iron.lowlevel`
-- only exposes the `repl_exists` predicate and has no getter.
local function python_repl()
  local meta = require("iron.state").get_repl("python")
  if meta and require("iron.lowlevel").repl_exists(meta) then
    return meta
  end
  return nil
end

function M.toggle_repl()
  local core = require("iron.core")
  if python_repl() then
    core.hide_repl("python")
  else
    core.repl_for("python")
  end
end

function M.focus_repl()
  require("iron.core").focus_on("python")
end

-- iron's close_repl only sends Ctrl-D, and repl_for then re-attaches the same
-- job, which leaves ipython sitting at its exit-confirmation prompt.
-- repl_restart replaces the process outright, but errors when there is nothing
-- to restart, so fall back to simply opening one.
function M.restart_repl()
  local core = require("iron.core")
  if python_repl() then
    core.repl_restart()
  else
    core.repl_for("python")
  end
end

-- Interrupt by sending SIGINT (ASCII 0x03) directly to the REPL's terminal
-- job channel. Going through iron.core.send would wrap it in bracketed-paste
-- and produce garbage instead of an interrupt.
function M.interrupt_repl()
  local meta = python_repl()
  if not meta or not meta.job then
    vim.notify("jupyter: no python REPL to interrupt", vim.log.levels.WARN)
    return
  end
  vim.fn.chansend(meta.job, string.char(3))
end

return M
