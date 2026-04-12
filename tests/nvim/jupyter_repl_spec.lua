local ok, repl = pcall(require, "jupyter.repl")
if not ok then
  io.stderr:write("FAIL: could not require jupyter.repl: " .. tostring(repl) .. "\n")
  os.exit(1)
end

local function reset_buf(lines)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

local function expect_range(name, got, want_s, want_e)
  if got == nil then
    if want_s == nil and want_e == nil then
      print("PASS: " .. name)
      return
    end
    io.stderr:write(("FAIL: %s: got nil, want %d..%d\n"):format(name, want_s, want_e))
    vim.cmd("cq! 1")
    return
  end
  if got[1] ~= want_s or got[2] ~= want_e then
    io.stderr:write(("FAIL: %s: got %d..%d, want %d..%d\n")
      :format(name, got[1], got[2], want_s or -1, want_e or -1))
    vim.cmd("cq! 1")
  else
    print("PASS: " .. name)
  end
end

-- Fixture:
--   1: "# %% a"
--   2: "print('a')"
--   3: "# %% b"
--   4: "print('b')"
--   5: "x = 1"
reset_buf({
  "# %% a",
  "print('a')",
  "# %% b",
  "print('b')",
  "x = 1",
})

-- range_for_cell excludes the marker line itself and clamps if the cell is empty.
expect_range("cell at line 2", repl.range_for_cell(0, 2), 2, 2)
expect_range("cell at line 4", repl.range_for_cell(0, 4), 4, 5)

-- Marker-only cell yields nil (nothing to send).
reset_buf({ "# %% a", "# %% b", "print('b')" })
expect_range("marker-only cell", repl.range_for_cell(0, 1), nil, nil)

-- range_for_above
reset_buf({
  "# %% a",
  "print('a')",
  "# %% b",
  "print('b')",
})
expect_range("above at line 4", repl.range_for_above(0, 4), 1, 2)
expect_range("above at first cell", repl.range_for_above(0, 2), nil, nil)

-- range_for_below
expect_range("below at line 2", repl.range_for_below(0, 2), 3, 4)

reset_buf({ "# %% a", "print('a')" })
expect_range("below in last cell", repl.range_for_below(0, 2), nil, nil)

print("ALL TESTS PASSED")
