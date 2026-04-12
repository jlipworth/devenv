-- Buffer-local keymaps for Jupyter cells. Called from config/autocmds.lua's
-- FileType autocmd. The `setup` function is idempotent per buffer because
-- vim.keymap.set with the same (mode, lhs, buffer) simply overwrites.

local cells = require("jupyter.cells")
local repl  = require("jupyter.repl")

local M = {}

function M.setup(bufnr)
  local map = function(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc, silent = true })
  end

  -- Execution / REPL
  map("n", "<localleader>jj", repl.run_cell,             "Jupyter: run cell")
  map("n", "<localleader>jn", repl.run_cell_and_advance, "Jupyter: run cell & advance")
  map("n", "<localleader>jl", repl.send_line,            "Jupyter: send line")
  map("x", "<localleader>js", repl.send_visual,          "Jupyter: send selection")
  map("n", "<localleader>jf", repl.send_file,            "Jupyter: send file")
  map("n", "<localleader>ja", repl.run_all_above,        "Jupyter: run above")
  map("n", "<localleader>jb", repl.run_all_below,        "Jupyter: run below")
  map("n", "<localleader>jr", repl.restart_repl,         "Jupyter: restart REPL")
  map("n", "<localleader>jk", repl.interrupt_repl,       "Jupyter: interrupt kernel")
  map("n", "<localleader>jt", repl.toggle_repl,          "Jupyter: toggle REPL")
  map("n", "<localleader>jo", repl.focus_repl,           "Jupyter: focus REPL")

  -- Navigation
  map({ "n", "x", "o" }, "]]", cells.goto_next_cell,  "Next cell")
  map({ "n", "x", "o" }, "[[", cells.goto_prev_cell,  "Prev cell")
  map({ "n", "x", "o" }, "]C", cells.goto_last_cell,  "Last cell")
  map({ "n", "x", "o" }, "[C", cells.goto_first_cell, "First cell")
end

-- mini.ai textobject spec for cells. `ai_type` is "a" or "i".
-- Returns nil when the cell has no code (e.g. two markers with nothing between).
function M.mini_ai_spec(ai_type)
  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local s = cells.cell_start(bufnr, line)
  local e = cells.cell_end(bufnr, line)
  if ai_type == "i" then
    local first = vim.api.nvim_buf_get_lines(bufnr, s - 1, s, false)[1]
    if first and first:match(cells.MARKER) then s = s + 1 end
    if s > e then return nil end
  end
  local last_line = vim.api.nvim_buf_get_lines(bufnr, e - 1, e, false)[1] or ""
  return {
    from = { line = s, col = 1 },
    to   = { line = e, col = math.max(1, #last_line) },
  }
end

return M
