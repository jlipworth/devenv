-- Headless spec for nvim/lua/jupyter/cells.lua
-- Uses plain Lua assert. On failure prints message and calls os.exit(1).

local ok, cells = pcall(require, "jupyter.cells")
if not ok then
  io.stderr:write("FAIL: could not require jupyter.cells: " .. tostring(cells) .. "\n")
  os.exit(1)
end

local function reset_buf(lines)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

local function expect_eq(name, got, want)
  if got ~= want then
    io.stderr:write(("FAIL: %s: got %s, want %s\n"):format(name, tostring(got), tostring(want)))
    vim.cmd("cq! 1")
  else
    print(("PASS: %s"):format(name))
  end
end

-- Fixture:  line 1: "# %% cell one"
--           line 2: "print('a')"
--           line 3: "# %% cell two"
--           line 4: "print('b')"
--           line 5: "x = 1"
reset_buf({
  "# %% cell one",
  "print('a')",
  "# %% cell two",
  "print('b')",
  "x = 1",
})

expect_eq("cell_start on marker line 1",  cells.cell_start(0, 1), 1)
expect_eq("cell_start inside cell 1",     cells.cell_start(0, 2), 1)
expect_eq("cell_start on marker line 3",  cells.cell_start(0, 3), 3)
expect_eq("cell_start inside cell 2",     cells.cell_start(0, 4), 3)
expect_eq("cell_end in cell 1",           cells.cell_end(0, 2),   2)
expect_eq("cell_end at marker line 3",    cells.cell_end(0, 3),   5)
expect_eq("cell_end in cell 2",           cells.cell_end(0, 4),   5)

-- Fixture with no markers: single implicit cell 1..N
reset_buf({ "print('a')", "x = 1" })
expect_eq("cell_start no marker",    cells.cell_start(0, 1), 1)
expect_eq("cell_end no marker",      cells.cell_end(0, 1),   2)

-- Fixture where a single-percent comment must NOT be treated as a marker.
reset_buf({
  "# % not a cell",
  "print('a')",
  "# %% real cell",
  "print('b')",
})
expect_eq("single-% ignored, implicit start", cells.cell_start(0, 2), 1)
expect_eq("double-%% is the real start",      cells.cell_start(0, 4), 3)

-- find_next / find_prev markers
reset_buf({
  "import os",
  "# %% first",
  "x = 1",
  "# %% second",
  "y = 2",
})
expect_eq("find_next from line 1",  cells.find_next_marker(0, 1), 2)
expect_eq("find_next from line 2",  cells.find_next_marker(0, 2), 4)
expect_eq("find_next no more",      cells.find_next_marker(0, 4), nil)
expect_eq("find_prev from line 5",  cells.find_prev_marker(0, 5), 4)
expect_eq("find_prev from line 4",  cells.find_prev_marker(0, 4), 2)
expect_eq("find_prev no earlier",   cells.find_prev_marker(0, 2), nil)

print("ALL TESTS PASSED")
