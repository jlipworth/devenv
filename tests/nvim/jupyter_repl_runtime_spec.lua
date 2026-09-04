-- Headless runtime spec for nvim/lua/jupyter/repl.lua.
--
-- The range helpers are covered by jupyter_repl_spec.lua. This spec covers the
-- parts that talk to iron.nvim: it stubs `iron.core`, `iron.lowlevel` and
-- `iron.state` through `package.preload` (the real plugin is not on the
-- runtimepath under `-u NONE`) and asserts both the calls made against iron and
-- that nothing raises.
--
-- The stubs deliberately mirror the pinned iron.nvim API: `iron.state.get_repl`
-- is the only REPL getter, `iron.lowlevel` exposes `repl_exists` but no getter.
-- A spec that passes against a stub with an `iron.lowlevel.get` would not have
-- caught the bug this file exists for.

local failures = 0

local function fail(name, msg)
  failures = failures + 1
  io.stderr:write(("FAIL: %s: %s\n"):format(name, msg))
end

local function expect_eq(name, got, want)
  if got ~= want then
    fail(name, ("got %s, want %s"):format(tostring(got), tostring(want)))
  else
    print("PASS: " .. name)
  end
end

local function expect_lines(name, got, want)
  if type(got) ~= "table" then
    fail(name, "got " .. tostring(got) .. ", want a table of lines")
    return
  end
  if #got ~= #want then
    fail(name, ("got %d lines (%s), want %d (%s)")
      :format(#got, table.concat(got, "|"), #want, table.concat(want, "|")))
    return
  end
  for i = 1, #want do
    if got[i] ~= want[i] then
      fail(name, ("line %d: got %q, want %q"):format(i, tostring(got[i]), want[i]))
      return
    end
  end
  print("PASS: " .. name)
end

-- --- iron.nvim stubs --------------------------------------------------------

-- Metadata returned by the fake `iron.state.get_repl`; set to nil to simulate
-- "no REPL has been started yet".
local stub_meta = nil
local calls = {}

local function record(name)
  return function(...)
    table.insert(calls, { name = name, args = { ... } })
  end
end

package.preload["iron.core"] = function()
  return {
    send = function(ft, lines)
      table.insert(calls, { name = "send", args = { ft, lines } })
    end,
    hide_repl = record("hide_repl"),
    repl_for = record("repl_for"),
    focus_on = record("focus_on"),
    close_repl = record("close_repl"),
    repl_restart = record("repl_restart"),
  }
end

package.preload["iron.lowlevel"] = function()
  return {
    -- Same predicate as the real lowlevel.repl_exists.
    repl_exists = function(meta)
      return meta ~= nil and vim.api.nvim_buf_is_loaded(meta.bufnr)
    end,
  }
end

package.preload["iron.state"] = function()
  return {
    get_repl = function(ft)
      if ft == nil or ft == "" then
        error("Empty filetype")
      end
      table.insert(calls, { name = "get_repl", args = { ft } })
      return stub_meta
    end,
  }
end

local ok, repl = pcall(require, "jupyter.repl")
if not ok then
  io.stderr:write("FAIL: could not require jupyter.repl: " .. tostring(repl) .. "\n")
  vim.cmd("cq! 1")
  return
end

-- Names of the iron calls recorded since the last reset, in order.
local function call_names()
  local names = {}
  for _, c in ipairs(calls) do
    table.insert(names, c.name)
  end
  return table.concat(names, ",")
end

local function find_call(name)
  for _, c in ipairs(calls) do
    if c.name == name then
      return c
    end
  end
  return nil
end

local function reset(lines)
  calls = {}
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines or { "" })
end

-- --- send_visual ------------------------------------------------------------

-- The '< and '> marks are only written when visual mode is left, so a
-- send_visual that reads them from inside visual mode sends the *previous*
-- selection. Seed a stale selection over lines 1..2, then select 3..4 and
-- assert the first invocation sends 3..4.
reset({ "a1", "a2", "b1", "b2", "c1" })
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.cmd("normal! Vj\27")
expect_eq("stale '< seeded at line 1", vim.fn.line("'<"), 1)
expect_eq("stale '> seeded at line 2", vim.fn.line("'>"), 2)

-- Bind exactly as nvim/lua/jupyter/keymaps.lua does: an x-mode mapping to a Lua
-- callback, which Neovim runs without leaving visual mode.
vim.keymap.set("x", "<F5>", repl.send_visual, { desc = "spec: send selection" })

calls = {}
vim.api.nvim_win_set_cursor(0, { 3, 0 })
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("Vj<F5>", true, false, true), "x", false)

local sent = find_call("send")
if sent == nil then
  fail("send_visual sends on first invocation", "iron.core.send was never called (calls: " .. call_names() .. ")")
else
  expect_eq("send_visual sends to python", sent.args[1], "python")
  expect_lines("send_visual sends the current selection", sent.args[2], { "b1", "b2" })
end

-- Second invocation over a different selection must track it too.
calls = {}
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("Vj<F5>", true, false, true), "x", false)
local sent2 = find_call("send")
if sent2 == nil then
  fail("send_visual sends on second invocation", "iron.core.send was never called")
else
  expect_lines("send_visual tracks a new selection", sent2.args[2], { "a1", "a2" })
end

vim.keymap.del("x", "<F5>")

-- --- toggle_repl ------------------------------------------------------------

-- A live REPL's metadata: bufnr must be a loaded buffer for repl_exists.
local live_meta = { ft = "python", bufnr = vim.api.nvim_get_current_buf() }

reset()
stub_meta = live_meta
local toggled_ok, toggle_err = pcall(repl.toggle_repl)
expect_eq("toggle_repl with a live REPL does not error", toggled_ok, true)
if not toggled_ok then
  fail("toggle_repl with a live REPL", tostring(toggle_err))
end
expect_eq("toggle_repl with a live REPL hides it", find_call("hide_repl") ~= nil, true)
expect_eq("toggle_repl with a live REPL does not open one", find_call("repl_for"), nil)

reset()
stub_meta = nil
local toggled_ok2, toggle_err2 = pcall(repl.toggle_repl)
expect_eq("toggle_repl without a REPL does not error", toggled_ok2, true)
if not toggled_ok2 then
  fail("toggle_repl without a REPL", tostring(toggle_err2))
end
expect_eq("toggle_repl without a REPL opens one", find_call("repl_for") ~= nil, true)

-- --- restart_repl -----------------------------------------------------------

reset()
stub_meta = live_meta
local restart_ok, restart_err = pcall(repl.restart_repl)
expect_eq("restart_repl with a live REPL does not error", restart_ok, true)
if not restart_ok then
  fail("restart_repl with a live REPL", tostring(restart_err))
end
expect_eq("restart_repl with a live REPL calls repl_restart", find_call("repl_restart") ~= nil, true)
-- close_repl only sends Ctrl-D; combined with repl_for it leaves ipython at its
-- exit-confirmation prompt, which is the bug repl_restart replaces.
expect_eq("restart_repl does not use close_repl", find_call("close_repl"), nil)

reset()
stub_meta = nil
local restart_ok2, restart_err2 = pcall(repl.restart_repl)
expect_eq("restart_repl without a REPL does not error", restart_ok2, true)
if not restart_ok2 then
  fail("restart_repl without a REPL", tostring(restart_err2))
end
expect_eq("restart_repl without a REPL opens one", find_call("repl_for") ~= nil, true)
expect_eq("restart_repl without a REPL skips repl_restart", find_call("repl_restart"), nil)

-- --- interrupt_repl ---------------------------------------------------------

-- A real `cat` job stands in for the REPL terminal: whatever interrupt_repl
-- writes to the channel comes straight back on stdout, so the spec can assert
-- the actual SIGINT byte (0x03) reached the channel rather than trusting a stub.
local echoed = {}
local job = vim.fn.jobstart({ "cat" }, {
  on_stdout = function(_, data)
    vim.list_extend(echoed, data)
  end,
})
if job <= 0 then
  fail("interrupt_repl setup", "could not start a `cat` job for the fake REPL channel")
else
  reset()
  stub_meta = { ft = "python", bufnr = vim.api.nvim_get_current_buf(), job = job }
  local interrupt_ok, interrupt_err = pcall(repl.interrupt_repl)
  expect_eq("interrupt_repl with a live REPL does not error", interrupt_ok, true)
  if not interrupt_ok then
    fail("interrupt_repl with a live REPL", tostring(interrupt_err))
  end
  vim.wait(2000, function()
    return table.concat(echoed):find(string.char(3), 1, true) ~= nil
  end, 20)
  expect_eq("interrupt_repl sends 0x03 to the REPL channel",
    table.concat(echoed):find(string.char(3), 1, true) ~= nil, true)
  vim.fn.jobstop(job)
end

reset()
stub_meta = nil
local notified
local real_notify = vim.notify
vim.notify = function(msg)
  notified = msg
end
local interrupt_ok2, interrupt_err2 = pcall(repl.interrupt_repl)
vim.notify = real_notify
expect_eq("interrupt_repl without a REPL does not error", interrupt_ok2, true)
if not interrupt_ok2 then
  fail("interrupt_repl without a REPL", tostring(interrupt_err2))
end
expect_eq("interrupt_repl without a REPL warns", notified ~= nil, true)

-- --- focus_repl -------------------------------------------------------------

reset()
stub_meta = live_meta
local focus_ok, focus_err = pcall(repl.focus_repl)
expect_eq("focus_repl does not error", focus_ok, true)
if not focus_ok then
  fail("focus_repl", tostring(focus_err))
end
expect_eq("focus_repl focuses python", find_call("focus_on") ~= nil, true)

if failures > 0 then
  io.stderr:write(("%d assertion(s) failed\n"):format(failures))
  vim.cmd("cq! 1")
else
  print("ALL TESTS PASSED")
end
