# Neovim Jupyter Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Jupyter notebook editing and IPython REPL integration to the Neovim config so `.ipynb` files open as readable Python with `# %%` cells, cells can be sent to a split-window IPython, and everything works on native Windows.

**Architecture:** One LazyVim plugin file (`plugins/jupyter.lua`) declaring the lone new plugin (`iron.nvim`) and wiring a `FileType` autocmd. Two pure helper modules (`jupyter/cells.lua` and `jupyter/repl.lua`) hold the cell-range and REPL-send logic. `.ipynb` read/write is handled by `BufReadCmd`/`BufWriteCmd` autocmds shelling out to the maintained `jupytext` CLI — no Neovim plugin for the file format, because no maintained one exists.

**Tech Stack:** Neovim 0.12, Lua, LazyVim, `Vigemus/iron.nvim` (REPL), `echasnovski/mini.hipatterns` (cell marker highlighting), `echasnovski/mini.ai` (cell textobjects — already in LazyVim base), `jupytext` + `ipython` + `ipykernel` CLIs installed via `uv tool install`.

---

## Spec Reference

Source spec: `docs/superpowers/specs/2026-04-12-nvim-jupyter-workflow-design.md`

Scope: Sub-project 1 of 4 in the Neovim Spacemacs-parity pass. AI assistants, Git parity, and debug/polish are separate plans.

## Amendment to Spec

The spec §2 lists `mini.hipatterns` as "already LazyVim-friendly" — strictly true, but LazyVim does **not** ship it enabled in the base. This plan adds it as a new plugin spec entry. Net plugin delta is **+2** (`iron.nvim` and `mini.hipatterns`), not +1 as written in spec §2. Both pass the maintenance rule (iron.nvim active Feb 2026, mini.nvim active daily).

## Review Revisions (post-code-reviewer)

This plan was reviewed by the code-reviewer agent before implementation and amended in place to fix the following blockers:

1. **Wiring lives in `config/autocmds.lua`, not a plugin piggyback.** Earlier drafts attached `require("jupyter.autocmds").setup()` to a `folke/lazy.nvim` plugin spec entry. That never runs — lazy.nvim special-cases its own spec and doesn't invoke user `config`. LazyVim's `lua/config/autocmds.lua` is the correct home (auto-loaded on `VeryLazy`, fires before any user-opened `.ipynb` buffer triggers `BufReadCmd`).
2. **`BufReadCmd` / `BufWriteCmd` use `nvim_buf_get_name`** (not `args.match`) and **fire `BufWritePost`** after successful write so format-on-save, gitsigns, and LSP sync stay functional on `.ipynb` buffers.
3. **`M.MARKER` pattern is strict**: `"^# %%%%"` (exactly `# %%`), not the looser `"^# %%"` which matched `# %` + anything.
4. **FileType autocmd pattern is `"python"` only** — the `"ipynb"` branch was dead (BufReadCmd sets filetype to `python`).
5. **`interrupt_repl` uses `chansend`** directly on the REPL terminal's job channel. Going through `iron.core.send` would wrap `^C` in bracketed-paste and produce garbage.
6. **`iron.nvim` is initialized with `keymaps = false`** — not an empty table — so iron's defaults do not silently collide with our buffer-local maps.
7. **`writefile` return value is checked** in `BufWriteCmd`.
8. **Test specs use `cq! 1`** (with bang) so the exit is reliable even when the test buffer is modified.
9. **Additional test fixtures**: a `# %` single-percent line must NOT be treated as a marker.

## File Structure

### Files created

- `nvim/lua/plugins/jupyter.lua` — LazyVim plugin specs for `iron.nvim`, `mini.hipatterns`, `mini.ai` cell-textobject contribution, and `which-key.nvim` group label. **No setup calls or FileType autocmds** — wiring lives in `config/autocmds.lua`.
- `nvim/lua/jupyter/cells.lua` — pure functions: cell-range computation, cell navigation. Everything takes explicit `bufnr`/`line` args so the module is unit-testable headlessly.
- `nvim/lua/jupyter/repl.lua` — send-to-iron wrappers. Depends on `cells.lua` and `iron.core`.
- `nvim/lua/jupyter/autocmds.lua` — pure `setup()` function that registers `BufReadCmd` / `BufWriteCmd` handlers for `*.ipynb` via `jupytext`. Called explicitly from `config/autocmds.lua`.
- `nvim/lua/jupyter/keymaps.lua` — `setup(bufnr)` function that installs all buffer-local maps (execution, navigation, manipulation, cheatsheet). Plus `mini_ai_spec(ai_type)` helper for cell textobjects.
- `tests/nvim/jupyter_cells_spec.lua` — headless assertions for `jupyter.cells`.
- `tests/nvim/jupyter_repl_spec.lua` — headless assertions for `jupyter.repl.range_for_*`.
- `tests/nvim/run_nvim_tests.sh` — shell driver that invokes `nvim --headless` against each `*_spec.lua`.

### Files modified

- `setup-dev-tools.ps1` — insert three `uv tool install` calls after the existing `# --- 5. uv ---` block.
- `prereq_packages.sh` — add the same three installs to `install_python_prereqs()`.
- `nvim/lua/config/autocmds.lua` — call `require("jupyter.autocmds").setup()` and register the `FileType` autocmd that calls `require("jupyter.keymaps").setup(bufnr)` for `python` filetype. LazyVim auto-loads this file on `VeryLazy`, so it runs before any user-opened `.ipynb` buffer can trigger `BufReadCmd`.
- `docs/NEOVIM_KEYBINDINGS.md` — append a new "Jupyter cells" section.

### Responsibility split rationale

- `cells.lua` knows about buffer lines and `# %%` markers. Nothing else.
- `repl.lua` knows about `cells.lua` and `iron`. Nothing about keymaps or autocmds.
- `autocmds.lua` shells `jupytext`. Knows nothing about cells or repl.
- `keymaps.lua` composes cells + repl into buffer-local maps.
- `plugins/jupyter.lua` declares plugins only.
- `config/autocmds.lua` is the **only** place where the jupyter modules are wired into live Neovim — this avoids the `folke/lazy.nvim`-piggyback anti-pattern (lazy.nvim does not run user `config` for its own spec).

This split keeps each module under 100 lines, makes `cells.lua` fully headless-testable without Iron or jupytext installed, and centralizes the side-effectful wiring in a single file that LazyVim auto-loads.

---

## Task 1: Install external dependencies in setup scripts

**Files:**
- Modify: `setup-dev-tools.ps1`
- Modify: `prereq_packages.sh`

- [ ] **Step 1: Inspect `setup-dev-tools.ps1` to find the exact insertion point after uv install**

Run: `grep -n "uv " /home/jlipworth/GNU_files/.worktrees/nvim-parity/setup-dev-tools.ps1 | head -20`

Expected: the comment `# --- 5. uv (Python manager) ---` block around line ~1045 followed by `# --- 6. Clone GNU_files repo ---` around line ~1073.

- [ ] **Step 2: Add Jupyter tool installs after uv is verified on PATH**

In `setup-dev-tools.ps1`, immediately before the `# --- 6. Clone GNU_files repo ---` comment, insert:

```powershell
# --- 5b. Jupyter Python tooling (via uv) ---
Write-Host "`n[5b/10] Installing Jupyter CLI tools via uv..." -ForegroundColor Yellow

foreach ($tool in @("jupytext", "ipython", "ipykernel")) {
    $alreadyInstalled = $false
    try {
        $toolList = & $uvCommand.Source tool list 2>$null
        if ($toolList -and ($toolList -match "^$tool\b")) {
            $alreadyInstalled = $true
        }
    } catch {}

    if (-not $alreadyInstalled) {
        Write-Host "Installing $tool via uv tool install..." -ForegroundColor Yellow
        $installArgs = @("tool", "install", $tool)
        if ($tool -eq "ipykernel") {
            $installArgs += @("--with", "ipython")
        }
        & $uvCommand.Source @installArgs
        if ($LASTEXITCODE -ne 0) {
            throw "uv tool install $tool failed with exit code $LASTEXITCODE."
        }
    } else {
        Write-Host "$tool already installed via uv." -ForegroundColor Green
    }
}

$jupyterToolPaths = Get-DirectoryCommandCandidatePaths `
    -Directories @("$env:USERPROFILE\.local\bin") `
    -BinaryNames @("jupytext", "ipython") `
    -IncludeExtensionless

$jupytextCommand = Wait-ForCommandInfo -Names @("jupytext") -CandidatePaths $jupyterToolPaths -TimeoutSeconds 15
if (-not $jupytextCommand) {
    throw "jupytext install completed but not on PATH. Check '$env:USERPROFILE\.local\bin'."
}
$ipythonCommand = Wait-ForCommandInfo -Names @("ipython") -CandidatePaths $jupyterToolPaths -TimeoutSeconds 15
if (-not $ipythonCommand) {
    throw "ipython install completed but not on PATH. Check '$env:USERPROFILE\.local\bin'."
}

$jupytextVersion = (& $jupytextCommand.Source --version).Trim()
$ipythonVersion  = (& $ipythonCommand.Source --version).Trim()
Write-Host "jupytext: $jupytextVersion | ipython: $ipythonVersion" -ForegroundColor Green
```

- [ ] **Step 3: Inspect `prereq_packages.sh` for the Python install function**

Run: `grep -n "install_python_prereqs\|pip install\|uv tool" /home/jlipworth/GNU_files/.worktrees/nvim-parity/prereq_packages.sh | head -30`

Expected: a function `install_python_prereqs()` and at least one `pip install` or `uv` invocation.

- [ ] **Step 4: Add the same three `uv tool install` calls to `install_python_prereqs()`**

Inside `install_python_prereqs()`, after the existing Python setup but before the function's closing `}`, insert:

```bash
  # Jupyter CLI tooling via uv (matches setup-dev-tools.ps1 behavior on Windows).
  if command -v uv >/dev/null 2>&1; then
    for tool in jupytext ipython; do
      if ! uv tool list 2>/dev/null | grep -q "^${tool}\b"; then
        echo "Installing ${tool} via uv tool install..."
        uv tool install "${tool}"
      fi
    done
    if ! uv tool list 2>/dev/null | grep -q "^ipykernel\b"; then
      echo "Installing ipykernel via uv tool install..."
      uv tool install ipykernel --with ipython
    fi
  else
    echo "WARNING: uv not found; skipping Jupyter CLI install. Run bootstrap.sh first."
  fi
```

- [ ] **Step 5: Verify locally on this Linux host**

Run:

```bash
uv tool install jupytext
uv tool install ipython
uv tool install ipykernel --with ipython
which jupytext ipython
jupytext --version
ipython --version
```

Expected: `jupytext` and `ipython` both resolve on PATH with version strings printed.

- [ ] **Step 6: Commit**

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-parity
git add setup-dev-tools.ps1 prereq_packages.sh
git commit -m "Wire Jupyter CLI installs into setup scripts"
```

---

## Task 2: Create the cells helper module with headless tests (TDD)

**Files:**
- Create: `nvim/lua/jupyter/cells.lua`
- Create: `tests/nvim/jupyter_cells_spec.lua`
- Create: `tests/nvim/run_nvim_tests.sh`

- [ ] **Step 1: Create the test runner shell script**

Write `tests/nvim/run_nvim_tests.sh`:

```bash
#!/usr/bin/env bash
# Run each *_spec.lua file under this directory via nvim --headless and aggregate results.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVIM_CONFIG="${HERE}/../../nvim"

fail=0
for spec in "${HERE}"/*_spec.lua; do
  echo "=== Running: $(basename "$spec") ==="
  if ! NVIM_APPNAME=_jupyter_test_dummy nvim --headless \
      --cmd "set runtimepath^=${NVIM_CONFIG}" \
      -u NONE \
      -c "luafile ${spec}" \
      -c "qall!" ; then
    fail=1
  fi
done
exit "$fail"
```

Make it executable:

```bash
chmod +x /home/jlipworth/GNU_files/.worktrees/nvim-parity/tests/nvim/run_nvim_tests.sh
```

- [ ] **Step 2: Write the failing test spec**

Write `tests/nvim/jupyter_cells_spec.lua`:

```lua
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
```

- [ ] **Step 3: Create an empty `cells.lua` and run tests to confirm failure**

Write `nvim/lua/jupyter/cells.lua`:

```lua
local M = {}
return M
```

Run:

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-parity
bash tests/nvim/run_nvim_tests.sh
```

Expected: output contains `FAIL:` lines (functions don't exist), exit code 1.

- [ ] **Step 4: Implement `cells.lua` to make tests pass**

Replace `nvim/lua/jupyter/cells.lua` with:

```lua
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
```

- [ ] **Step 5: Run tests and verify they pass**

Run:

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-parity
bash tests/nvim/run_nvim_tests.sh
```

Expected: no `FAIL:` lines; final line `ALL TESTS PASSED`; exit code 0.

- [ ] **Step 6: Commit**

```bash
git add nvim/lua/jupyter/cells.lua tests/nvim/
git commit -m "Add jupyter.cells helper module with headless tests"
```

---

## Task 3: Add jupytext `.ipynb` read/write autocmds

**Files:**
- Create: `nvim/lua/jupyter/autocmds.lua`

- [ ] **Step 1: Write autocmds module**

Write `nvim/lua/jupyter/autocmds.lua`:

```lua
-- BufReadCmd / BufWriteCmd for *.ipynb: transparently round-trip via the
-- jupytext CLI. Keeps the buffer as filetype=python with `# %%` markers.

local M = {}

local function notify_err(msg)
  vim.notify("jupyter: " .. msg, vim.log.levels.ERROR)
end

-- Read .ipynb via `jupytext --to py:percent --output - <path>`.
-- Uses nvim_buf_get_name to get the real path (args.match may be a pattern
-- expansion that drops the directory component on some platforms).
local function on_read(args)
  local path = vim.api.nvim_buf_get_name(args.buf)
  if path == "" then path = args.match end
  local result = vim.fn.systemlist({ "jupytext", "--to", "py:percent", "--output", "-", path })
  if vim.v.shell_error ~= 0 then
    notify_err("jupytext read failed for " .. path)
    return
  end
  vim.api.nvim_buf_set_lines(args.buf, 0, -1, false, result)
  vim.bo[args.buf].filetype = "python"
  vim.bo[args.buf].modified = false
end

-- Write .ipynb by piping current buffer lines to jupytext.
-- Fires BufWritePost on success so format-on-save, gitsigns, LSP sync keep working.
local function on_write(args)
  local path = vim.api.nvim_buf_get_name(args.buf)
  if path == "" then path = args.match end
  local lines = vim.api.nvim_buf_get_lines(args.buf, 0, -1, false)
  local tmp = vim.fn.tempname() .. ".py"
  if vim.fn.writefile(lines, tmp) ~= 0 then
    notify_err("failed to write temp buffer for " .. path)
    return
  end
  vim.fn.system({ "jupytext", "--from", "py:percent", "--to", "ipynb",
                  "--output", path, tmp })
  local rc = vim.v.shell_error
  vim.fn.delete(tmp)
  if rc ~= 0 then
    notify_err("jupytext write failed for " .. path)
    return
  end
  vim.bo[args.buf].modified = false
  vim.api.nvim_exec_autocmds("BufWritePost", {
    buffer = args.buf,
    modeline = false,
  })
end

function M.setup()
  local group = vim.api.nvim_create_augroup("JupyterIpynb", { clear = true })
  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = group,
    pattern = "*.ipynb",
    callback = on_read,
  })
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    group = group,
    pattern = "*.ipynb",
    callback = on_write,
  })
end

return M
```

- [ ] **Step 2: Verify module loads headlessly**

Run:

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-parity
nvim --headless --cmd "set runtimepath^=./nvim" -u NONE \
  -c 'lua require("jupyter.autocmds").setup(); print("OK")' -c 'qall' 2>&1 | tail -3
```

Expected: output contains `OK`; no Lua tracebacks.

- [ ] **Step 3: Create a fixture notebook and verify read/write round-trip**

Run:

```bash
cat > /tmp/jup_smoke.py <<'EOF'
# %%
print("hello")
# %%
x = 1 + 1
EOF
jupytext --to ipynb /tmp/jup_smoke.py
test -f /tmp/jup_smoke.ipynb && echo "fixture created"
```

- [ ] **Step 4: Verify BufReadCmd path works in a non-interactive nvim run**

Run:

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-parity
nvim --headless --cmd "set runtimepath^=./nvim" -u NONE \
  -c 'lua require("jupyter.autocmds").setup()' \
  -c 'edit /tmp/jup_smoke.ipynb' \
  -c 'lua io.write(vim.api.nvim_buf_get_lines(0, 0, 2, false)[1] .. "\n")' \
  -c 'qall!' 2>&1 | tail -3
```

Expected: first line of output is `# %%` (or `# %% [markdown]` for richer notebooks). If it prints `{"cells":` you're reading raw JSON — the autocmd did not fire.

- [ ] **Step 5: Commit**

```bash
git add nvim/lua/jupyter/autocmds.lua
git commit -m "Add jupytext-based BufReadCmd/BufWriteCmd for .ipynb"
```

---

## Task 4: Add iron.nvim and mini.hipatterns plugin specs

**Files:**
- Create: `nvim/lua/plugins/jupyter.lua`

- [ ] **Step 1: Write plugin spec with iron.nvim and mini.hipatterns only**

Write `nvim/lua/plugins/jupyter.lua`:

```lua
-- Jupyter / .ipynb editing. See docs/superpowers/specs/2026-04-12-nvim-jupyter-workflow-design.md
-- Plugin delta: +2 (iron.nvim for REPL, mini.hipatterns for # %% marker highlight).
-- mini.ai contribution and which-key group are added in Task 7.
-- The setup calls and FileType autocmd live in config/autocmds.lua (Task 6)
-- — NOT here, because lazy.nvim does not run user `config` blocks for its
-- own spec entry, and every other plugin-piggyback is brittle.

return {
  -- REPL sender: current buffer/visual/line -> external IPython via :terminal.
  {
    "Vigemus/iron.nvim",
    cmd = { "IronRepl", "IronAttach", "IronSend", "IronFocus" },
    config = function()
      local iron = require("iron.core")
      local view = require("iron.view")
      iron.setup({
        config = {
          scratch_repl = true,
          repl_definition = {
            python = {
              command = { "ipython", "--no-autoindent" },
              format = require("iron.fts.common").bracketed_paste_python,
            },
          },
          repl_open_cmd = view.split.vertical.botright("40%"),
        },
        -- Disable iron's default keymaps entirely; ours are installed per-buffer
        -- by jupyter.keymaps (Task 6) and must not collide with iron defaults.
        keymaps = false,
        highlight = { italic = true },
        ignore_blank_lines = true,
      })
    end,
  },

  -- Visual highlight for # %% cell markers.
  -- Lua pattern: %%%% matches literal %% (each %% = one literal %).
  {
    "echasnovski/mini.hipatterns",
    event = { "BufReadPost *.py", "BufReadPost *.ipynb", "BufNewFile *.py" },
    opts = function(_, opts)
      opts.highlighters = opts.highlighters or {}
      opts.highlighters.jupyter_cell = {
        pattern = "^# %%%%.*$",
        group = "Title",
      }
      return opts
    end,
  },
}
```

- [ ] **Step 2: Verify parse + iron loads headlessly (requires the full lazy stack)**

Because this file references `require("iron.core")` inside `config`, it only runs after lazy installs iron. To verify the spec *file* parses without error:

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-parity
nvim --headless --cmd "set runtimepath^=./nvim" -u NONE \
  -c 'luafile ./nvim/lua/plugins/jupyter.lua' \
  -c 'qall!' 2>&1 | tail -3
```

Expected: empty output (module returned a table). Any Lua traceback means fix the file before moving on.

- [ ] **Step 3: Drive lazy sync in the full config and confirm iron is installed**

This requires pointing `NVIM_APPNAME` at the worktree config. The simplest is to symlink it on this Linux host for testing only:

```bash
mkdir -p ~/.config
if [ -e ~/.config/nvim_parity_test ] && [ ! -L ~/.config/nvim_parity_test ]; then
  echo "ERROR: ~/.config/nvim_parity_test exists and is not a symlink" && exit 1
fi
ln -sfn /home/jlipworth/GNU_files/.worktrees/nvim-parity/nvim ~/.config/nvim_parity_test
NVIM_APPNAME=nvim_parity_test nvim --headless "+Lazy! sync" +qa 2>&1 | tail -20
```

Expected: lazy installs `iron.nvim` and `mini.hipatterns`. No Lua errors.

- [ ] **Step 4: Run checkhealth for iron**

```bash
NVIM_APPNAME=nvim_parity_test nvim --headless \
  -c 'checkhealth iron' -c 'qall' 2>&1 | grep -iE "error|fail|warn" | head -10
```

Expected: no `ERROR:` or `FAIL:` lines. `WARN:` about optional providers is acceptable.

- [ ] **Step 5: Commit**

```bash
git add nvim/lua/plugins/jupyter.lua
git commit -m "Add iron.nvim + mini.hipatterns plugin specs for Jupyter"
```

---

## Task 5: Create REPL wrappers with headless tests

**Files:**
- Create: `nvim/lua/jupyter/repl.lua`
- Modify: `tests/nvim/jupyter_cells_spec.lua` → rename conceptually; add new `jupyter_repl_spec.lua` that tests the pure range computation without requiring iron

Rationale: we can test range *computation* (which ranges we'd send) without actually calling iron. We split repl into two layers: a pure `range_for_*` set of functions, and the send wrappers that pipe ranges to iron.

- [ ] **Step 1: Write the spec for range computation**

Write `tests/nvim/jupyter_repl_spec.lua`:

```lua
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
```

- [ ] **Step 2: Stub `repl.lua` and confirm failure**

Write `nvim/lua/jupyter/repl.lua`:

```lua
local M = {}
return M
```

Run:

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-parity
bash tests/nvim/run_nvim_tests.sh
```

Expected: `FAIL: cell at line 2: ...` (function `range_for_cell` doesn't exist), exit 1.

- [ ] **Step 3: Implement range functions + send wrappers**

Replace `nvim/lua/jupyter/repl.lua` with:

```lua
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
```

- [ ] **Step 4: Run tests and verify pass**

Run:

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-parity
bash tests/nvim/run_nvim_tests.sh
```

Expected: no `FAIL:` lines; `ALL TESTS PASSED` printed for both spec files.

- [ ] **Step 5: Commit**

```bash
git add nvim/lua/jupyter/repl.lua tests/nvim/jupyter_repl_spec.lua
git commit -m "Add jupyter.repl module with range tests and iron send wrappers"
```

---

## Task 6: Create keymaps module and wire FileType autocmd via config/autocmds.lua

**Files:**
- Create: `nvim/lua/jupyter/keymaps.lua`
- Modify: `nvim/lua/config/autocmds.lua`

- [ ] **Step 1: Write the keymaps module**

Write `nvim/lua/jupyter/keymaps.lua`:

```lua
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
```

- [ ] **Step 2: Extend `nvim/lua/config/autocmds.lua` with the Jupyter wiring**

Append to `nvim/lua/config/autocmds.lua` (LazyVim auto-loads this file on `VeryLazy`, which fires before any user buffer read, so the BufReadCmd is in place when the first `.ipynb` is opened):

```lua

-- === Jupyter cell workflow ===================================================
-- See docs/superpowers/specs/2026-04-12-nvim-jupyter-workflow-design.md.
-- BufReadCmd/BufWriteCmd for *.ipynb and buffer-local keymaps for python files.

require("jupyter.autocmds").setup()

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("JupyterFiletype", { clear = true }),
  pattern = "python",  -- BufReadCmd normalizes .ipynb -> python; no "ipynb" branch needed
  callback = function(args)
    require("jupyter.keymaps").setup(args.buf)
  end,
})
```

- [ ] **Step 3: Verify the modified autocmds file parses in isolation**

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-parity
nvim --headless --cmd "set runtimepath^=./nvim" -u NONE \
  -c 'luafile ./nvim/lua/config/autocmds.lua' -c 'qall!' 2>&1 | tail -5
```

Expected: output will contain one error about `require("jupyter.autocmds")` failing because no runtimepath resolves it to the worktree's `nvim/lua/jupyter/`. That's fine for parse — the next step verifies the full flow.

- [ ] **Step 4: Drive the full config via the test symlink and confirm wiring fires**

```bash
mkdir -p ~/.config
if [ -e ~/.config/nvim_parity_test ] && [ ! -L ~/.config/nvim_parity_test ]; then
  echo "ERROR: ~/.config/nvim_parity_test exists and is not a symlink" && exit 1
fi
ln -sfn /home/jlipworth/GNU_files/.worktrees/nvim-parity/nvim ~/.config/nvim_parity_test

# Opening any .ipynb should trigger BufReadCmd (jupytext) then FileType=python
# (keymaps). Verify the ]] map is buffer-local installed.
NVIM_APPNAME=nvim_parity_test nvim --headless \
  /tmp/jup_smoke.ipynb \
  -c 'doautocmd User VeryLazy' \
  -c 'lua io.write("maparg_]]:" .. vim.fn.maparg("]]", "n") .. "\n")' \
  -c 'lua io.write("filetype:" .. vim.bo.filetype .. "\n")' \
  -c 'qall!' 2>&1 | tail -10
```

Expected: `filetype:python` and a non-empty `maparg_]]:` string (the Lua function reference shows as a hash-ish string, not empty).

- [ ] **Step 5: Commit**

```bash
git add nvim/lua/jupyter/keymaps.lua nvim/lua/config/autocmds.lua
git commit -m "Wire Jupyter keymaps via config/autocmds.lua FileType autocmd"
```

---

## Task 7: Add cell manipulation maps, cell textobjects, and which-key group

**Files:**
- Modify: `nvim/lua/jupyter/keymaps.lua`
- Modify: `nvim/lua/plugins/jupyter.lua`

- [ ] **Step 1: Extend `nvim/lua/jupyter/keymaps.lua` with cell-manipulation maps and the cheatsheet popup**

In `nvim/lua/jupyter/keymaps.lua`, inside `M.setup(bufnr)`, immediately before the function's closing `end`, insert:

```lua
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
    vim.api.nvim_open_win(buf, true, {
      relative = "editor", border = "rounded",
      width = 60, height = #lines + 1,
      row = math.floor((vim.o.lines - #lines) / 2) - 2,
      col = math.floor((vim.o.columns - 60) / 2),
      style = "minimal", title = " Jupyter ", title_pos = "center",
    })
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, nowait = true })
  end, "Jupyter: cheatsheet")
```

- [ ] **Step 2: Add mini.ai and which-key plugin entries to `nvim/lua/plugins/jupyter.lua`**

In `nvim/lua/plugins/jupyter.lua`, add two more entries to the returned table (after the `mini.hipatterns` entry):

```lua
  -- mini.ai textobjects for cells. `aj` includes the `# %%` marker, `ij` excludes it.
  {
    "echasnovski/mini.ai",
    optional = true,
    opts = function(_, opts)
      opts.custom_textobjects = opts.custom_textobjects or {}
      opts.custom_textobjects.j = function(ai_type)
        return require("jupyter.keymaps").mini_ai_spec(ai_type)
      end
      return opts
    end,
  },

  -- which-key group label for <localleader>j
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<localleader>j", group = "jupyter", mode = { "n", "x" } },
      },
    },
  },
```

- [ ] **Step 3: Verify the spec file still parses**

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-parity
nvim --headless --cmd "set runtimepath^=./nvim" -u NONE \
  -c 'luafile ./nvim/lua/plugins/jupyter.lua' -c 'qall!' 2>&1 | tail -3
```

Expected: empty output.

- [ ] **Step 4: Lazy-sync in the test profile and verify no Lua errors**

```bash
NVIM_APPNAME=nvim_parity_test nvim --headless "+Lazy! sync" +qa 2>&1 | tail -20
```

Expected: no errors. mini.ai and mini.hipatterns installed if not already.

- [ ] **Step 5: Verify `aj` textobject resolves in a fixture buffer**

```bash
NVIM_APPNAME=nvim_parity_test nvim --headless \
  /tmp/jup_smoke.ipynb \
  -c 'normal! ggj' \
  -c 'lua vim.cmd("normal vaj"); io.write(tostring(vim.fn.line("'\''>")) .. "\n")' \
  -c 'qall!' 2>&1 | tail -3
```

Expected: a numeric end-of-selection line > 1. Exact value depends on fixture but should be 2 for cell one of the smoke notebook.

- [ ] **Step 6: Commit**

```bash
git add nvim/lua/plugins/jupyter.lua
git commit -m "Add Jupyter cell textobjects, which-key group, and cheatsheet popup"
```

---

## Task 8: Update `docs/NEOVIM_KEYBINDINGS.md`

**Files:**
- Modify: `docs/NEOVIM_KEYBINDINGS.md`

- [ ] **Step 1: Inspect the current doc structure to find where to insert**

Run: `head -60 /home/jlipworth/GNU_files/.worktrees/nvim-parity/docs/NEOVIM_KEYBINDINGS.md`

Locate a top-level section such as "File/buffer/search" or similar; the new section goes after that.

- [ ] **Step 2: Append a Jupyter cells section**

Append the following at the end of `docs/NEOVIM_KEYBINDINGS.md`:

```markdown

## Jupyter cells (in `.py` / `.ipynb` buffers)

`.ipynb` files are opened as Python with `# %%` cell markers via the
`jupytext` CLI. Plots and real-kernel runs still live in your browser
Jupyter session — the Neovim REPL is plain IPython.

### Execution (leader is `,`)

| Keys | Action |
|---|---|
| `,jj` | Run current cell |
| `,jn` | Run current cell, advance to next |
| `,jl` | Send current line |
| `,js` | Send visual selection (visual mode) |
| `,jf` | Send entire file |
| `,ja` | Run all cells above current |
| `,jb` | Run all cells below current |
| `,jr` | Restart IPython REPL |
| `,jk` | Interrupt kernel (Ctrl-C) |
| `,jt` | Toggle REPL window |
| `,jo` | Focus REPL split |

### Manipulation

| Keys | Action |
|---|---|
| `,ji` | Insert new cell below current |
| `,jI` | Insert new cell above current |
| `,jx` | Delete current cell |

### Navigation

| Keys | Action |
|---|---|
| `]]` | Next cell |
| `[[` | Previous cell |
| `]C` | Last cell |
| `[C` | First cell |
| `aj` | Around cell textobject (incl. marker) |
| `ij` | Inside cell textobject (code only) |

### Cheatsheet popup

`,?` in a Python/ipynb buffer shows the above in a floating window.

### Spacemacs translation

| Spacemacs | Neovim here |
|---|---|
| `SPC m s b` (send buffer) | `,jf` |
| `SPC m s f` (send function) | visual-select then `,js` |
| `SPC m s r` (send region) | visual-select then `,js` |
| `SPC m s s` (swap to REPL) | `,jo` |
| *(new)* | `,jj` = run cell (was not a Spacemacs verb) |
```

- [ ] **Step 3: Commit**

```bash
git add docs/NEOVIM_KEYBINDINGS.md
git commit -m "Document Jupyter cell bindings in NEOVIM_KEYBINDINGS.md"
```

---

## Task 9: Full validation pass

- [ ] **Step 1: Run all nvim-test specs**

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-parity
bash tests/nvim/run_nvim_tests.sh
```

Expected: two `ALL TESTS PASSED` lines (cells + repl), exit 0.

- [ ] **Step 2: Headless config parse**

```bash
NVIM_APPNAME=nvim_parity_test nvim --headless -c 'qall' 2>&1 | tail -5
```

Expected: empty. Any stderr = config error to fix.

- [ ] **Step 3: checkhealth iron**

```bash
NVIM_APPNAME=nvim_parity_test nvim --headless -c 'checkhealth iron' -c 'qall' 2>&1 | grep -iE "^\s*(error|fail)" | head
```

Expected: no output.

- [ ] **Step 4: Module load sanity**

```bash
NVIM_APPNAME=nvim_parity_test nvim --headless \
  -c 'lua require("jupyter.cells"); require("jupyter.repl"); require("jupyter.autocmds"); print("OK")' \
  -c 'qall' 2>&1 | tail -3
```

Expected: `OK`.

- [ ] **Step 5: Lazy plugin count bumped by 2**

```bash
NVIM_APPNAME=nvim_parity_test nvim --headless \
  -c 'lua print(require("lazy").stats().count)' -c 'qall' 2>&1 | tail -3
```

Record the number. On `master` the count should be 2 fewer. (This is an informational sanity check, not a hard assertion.)

- [ ] **Step 6: Manual smoke test on the Linux host**

Open Neovim against the fixture notebook **interactively** (requires a real terminal):

```bash
NVIM_APPNAME=nvim_parity_test nvim /tmp/jup_smoke.ipynb
```

Verify in order:

1. Buffer shows `# %%` + Python code, not JSON.
2. `:set filetype?` → `filetype=python`.
3. `]]` moves cursor to `# %%` of cell two.
4. `[[` returns to cell one.
5. `,jj` opens a vertical split with IPython running; `hello` appears.
6. `,jn` on cell one: `hello` re-prints; cursor advances to cell two.
7. `,jj` on cell two: a number (2.0) appears.
8. `vij` in cell two: visual selection covers only the code line.
9. `,?` → cheatsheet floating window appears; close with `q`.
10. `:w` — no error. In another terminal, `jupytext --to py:percent /tmp/jup_smoke.ipynb -o -` shows the same content.

- [ ] **Step 7: If any smoke-test step fails**

Use `superpowers:headless-editor-debugging` and `superpowers:systematic-debugging`. Write a fix, re-run the test runner and the failing smoke step. Commit each fix separately.

- [ ] **Step 8: Final commit if any validation fixups happened**

```bash
git add -A
git diff --cached --stat
git commit -m "Fixups from Jupyter workflow validation"
```

(Skip if no changes.)

- [ ] **Step 9: Clean up the test symlink**

```bash
rm ~/.config/nvim_parity_test
```

---

## Self-Review

### Spec coverage

- §1 Goal: `.ipynb` opens as Python → Task 3 (autocmds) + Task 6 (config/autocmds wiring). Cell navigation → Task 6. REPL in split → Task 4 + 5. Cross-platform → Task 1 installs tooling on both Windows and Unix.
- §1 Success criteria:
  - Criterion 1 (`.ipynb` shows Python): Task 9 smoke step 1.
  - Criterion 2 (save round-trips to valid `.ipynb`): Task 9 smoke step 10.
  - Criterion 3 (`<localleader>jj` works within ~1s after warm-up): Task 9 smoke step 5.
  - Criterion 4 (`]]` / `[[` navigation): Task 9 smoke steps 3–4.
  - Criterion 5 (works on Windows): verified out-of-band by the user; wiring is in Task 1.
- §2 Plugin stack: iron + mini.hipatterns → Task 4. mini.ai + which-key → Task 7. DIY cells → Task 2. DIY repl glue → Task 5. DIY autocmds → Task 3. Wiring into live Neovim → Task 6 via `config/autocmds.lua`.
- §3 Keymaps: execution + navigation → Task 6. Cell manipulation + textobjects + which-key group + cheatsheet popup → Task 7.
- §4 Install wiring: Task 1 (both scripts).
- §5 Implementation structure: reflected in File Structure section + task split.
- §6 Testing: headless tests → Tasks 2 & 5 (pure helpers). Smoke test → Task 9.
- §7 Documentation → Task 8.

No spec requirements without a task.

### Placeholder scan

Checked for TBD, TODO, FIXME, "similar to", "appropriate error handling", "add tests for the above". None present.

### Type consistency

Functions used across tasks:

- `cells.MARKER`, `cells.cell_start`, `cells.cell_end`, `cells.current_cell_range`, `cells.find_next_marker`, `cells.find_prev_marker`, `cells.goto_next_cell`, `cells.goto_prev_cell`, `cells.goto_first_cell`, `cells.goto_last_cell` — defined in Task 2, referenced in Tasks 5–7.
- `repl.range_for_cell`, `repl.range_for_above`, `repl.range_for_below`, `repl.run_cell`, `repl.run_cell_and_advance`, `repl.run_all_above`, `repl.run_all_below`, `repl.send_line`, `repl.send_file`, `repl.send_visual`, `repl.toggle_repl`, `repl.focus_repl`, `repl.restart_repl`, `repl.interrupt_repl` — defined in Task 5, referenced in Task 6.
- `autocmds.setup` — defined in Task 3, called from `config/autocmds.lua` in Task 6.
- `keymaps.setup(bufnr)`, `keymaps.mini_ai_spec(ai_type)` — defined in Task 6, extended in Task 7, called from `config/autocmds.lua` and `plugins/jupyter.lua`.

All names consistent.
