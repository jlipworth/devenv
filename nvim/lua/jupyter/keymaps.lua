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

  -- Cell manipulation
  map("n", "<localleader>ji", function()
    local line = vim.api.nvim_win_get_cursor(0)[1]
    local e = cells.cell_end(0, line)
    vim.api.nvim_buf_set_lines(0, e, e, false, { "# %%", "" })
    vim.api.nvim_win_set_cursor(0, { e + 2, 0 })
  end, "Jupyter: insert cell below")

  map("n", "<localleader>jI", function()
    local line = vim.api.nvim_win_get_cursor(0)[1]
    local s = cells.cell_start(0, line)
    vim.api.nvim_buf_set_lines(0, s - 1, s - 1, false, { "# %%", "" })
    vim.api.nvim_win_set_cursor(0, { s + 1, 0 })
  end, "Jupyter: insert cell above")

  map("n", "<localleader>jx", function()
    local line = vim.api.nvim_win_get_cursor(0)[1]
    local s = cells.cell_start(0, line)
    local e = cells.cell_end(0, line)
    vim.api.nvim_buf_set_lines(0, s - 1, e, false, {})
  end, "Jupyter: delete cell")

  -- Buffer-local cheatsheet popup
  map("n", "<localleader>?", function()
    local lines = {
      "Jupyter bindings (buffer-local):",
      "",
      "  <localleader>jj  run cell            <localleader>jn  run & advance",
      "  <localleader>jl  send line           <localleader>js  send selection",
      "  <localleader>jf  send file           <localleader>ja  run above",
      "  <localleader>jb  run below           <localleader>jr  restart REPL",
      "  <localleader>jk  interrupt kernel    <localleader>jt  toggle REPL",
      "  <localleader>jo  focus REPL",
      "",
      "  <localleader>ji  insert cell below   <localleader>jI  insert cell above",
      "  <localleader>jx  delete cell",
      "",
      "  ]]  next cell    [[  prev cell    ]C  last cell    [C  first cell",
      "  aj  around cell (incl. marker)   ij  inside cell (code only)",
    }
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.bo[buf].bufhidden = "wipe"
    local width = math.min(60, vim.o.columns - 4)
    vim.api.nvim_open_win(buf, true, {
      relative = "editor", border = "rounded",
      width = width, height = #lines + 1,
      row = math.floor((vim.o.lines - #lines) / 2) - 2,
      col = math.floor((vim.o.columns - width) / 2),
      style = "minimal", title = " Jupyter ", title_pos = "center",
    })
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, nowait = true })
  end, "Jupyter: cheatsheet")
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
