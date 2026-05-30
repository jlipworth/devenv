# Neovim Jupyter + Python Cell Workflow — Design

Date: 2026-04-12
Status: Draft (awaiting user review)
Branch: `feature/nvim-parity`
Scope: Sub-project 1 of 4 in the Neovim Spacemacs-parity pass.

## 1. Goal & Non-Goals

### Goal

Edit `.ipynb` files in Neovim as readable Python with `# %%` cell markers,
navigate between cells, and send cells to an interactive IPython REPL in a side
split. Save back to `.ipynb` transparently. Works identically on Linux and
native Windows (Alacritty terminal, no WSL).

### Non-Goals

- Inline plot rendering. Plots stay in the user's browser-hosted Jupyter
  server. No Molten, no `image.nvim`, no terminal switch required.
- Running a Jupyter kernel inside Neovim. The REPL is plain IPython, not a
  Jupyter kernel session. The browser notebook server is untouched.
- Replacing the browser workflow. This augments it for cases where the user
  wants to edit cells without round-tripping through the JupyterLab UI.
- Windows CI. Manual verification only on Windows.

### Success Criteria

1. `nvim foo.ipynb` opens the notebook as Python with `# %%` cell markers, not
   raw JSON.
2. Saving writes a valid `.ipynb` that reopens cleanly in JupyterLab.
3. `<localleader>jj` sends the current cell to an IPython REPL and output is
   visible in a split within ~1 second of the send (after the REPL is warm;
   cold-start of IPython itself is allowed ~2s on first launch).
4. `]]` and `[[` navigate forward/backward between cells.
5. Every item above works on the Windows install produced by
   `setup-dev-tools.ps1` with no additional admin prompts.

## 2. Plugin Stack

The Neovim Jupyter ecosystem's two dedicated ipynb plugins
(`GCBallesteros/jupytext.nvim` and `NotebookNavigator.nvim`) are abandoned
(~24 months without commits). `goerz/jupytext.vim` is archived. The load-bearing
piece — the `jupytext` CLI (`mwouts/jupytext`) — is actively maintained.

Because no maintained `.ipynb` ↔ `.py` Neovim plugin exists, we do that layer
ourselves via ~30 lines of Lua shelling out to the CLI. This aligns with the
project-wide no-abandonware rule.

| Component | Mechanism |
|---|---|
| `.ipynb` ↔ `.py:percent` conversion | DIY Lua autocmds in `nvim/lua/plugins/jupyter.lua` calling `jupytext` CLI |
| Cell highlighting (`# %%` marker visualization) | `echasnovski/mini.hipatterns` (active daily) |
| Cell navigation (`]]` / `[[`) | DIY Lua using `vim.fn.search("^# %%")` |
| Cell textobjects (`aj` / `ij`) | Custom `mini.ai` spec (already in LazyVim) |
| REPL (IPython, send cell/region/line) | `Vigemus/iron.nvim` — verified healthy, recent Windows fixes |
| "Send current cell" / "run above" / etc. | DIY Lua glue wrapping iron's `send` API with cell-range computation |

Net plugin delta: **+1** (`iron.nvim`). `mini.hipatterns` and `mini.ai`
already ship with the LazyVim base.

### External Dependencies (CLI tools)

- `jupytext` (upstream: `mwouts/jupytext`) — installed via `uv tool install jupytext`.
- `ipython` — installed via `uv tool install ipython`.
- `ipykernel` — installed via `uv tool install ipykernel --with ipython`.

All three live under `~/.local/bin` (Unix) or `%USERPROFILE%\.local\bin`
(Windows), both of which the existing install scripts already add to PATH.

### Rejected Alternatives

- **`benlubas/molten-nvim`** — runs its own Jupyter kernel; redundant with
  iron.nvim. Would be required if we wanted inline plots, but we explicitly
  don't.
- **`quarto-dev/quarto-nvim`** — healthy, but `.qmd`-centric and overshoots our
  scope. Adds `otter.nvim` and Quarto CLI dependencies for features we don't
  use.
- **`vim-slime`** — requires an external multiplexer (tmux/kitty/wezterm) as
  the paste target. User runs Alacritty on Windows without tmux, so this
  pins them to a tool they don't otherwise need.
- **`jupynium.nvim`** — Selenium-based browser automation. Overkill when the
  user is already comfortable using the browser UI for real execution.

## 3. Keymap Layout

All Jupyter-specific maps live under `<localleader>` (`,` in this config —
same convention as Spacemacs major-mode prefixes) and are buffer-local to the
`python` and `ipynb` filetypes. Navigation motions and textobjects are also
buffer-local.

### Cell Execution / REPL — `<localleader>j` subtree

| Keys | Action |
|---|---|
| `<localleader>jj` | Run current cell |
| `<localleader>jn` | Run current cell, advance to next |
| `<localleader>jl` | Send current line |
| `<localleader>js` | Send visual selection (visual mode) |
| `<localleader>jf` | Send entire file |
| `<localleader>ja` | Run all cells above current |
| `<localleader>jb` | Run all cells below current |
| `<localleader>jr` | Restart IPython REPL |
| `<localleader>jk` | Interrupt kernel (send Ctrl-C) |
| `<localleader>jt` | Toggle REPL window visibility |
| `<localleader>jo` | Open/focus REPL split |

### Cell Manipulation — `<localleader>j` subtree

| Keys | Action |
|---|---|
| `<localleader>ji` | Insert new cell below current |
| `<localleader>jI` | Insert new cell above current |
| `<localleader>jx` | Delete current cell (including marker) |

### Cell Navigation

| Keys | Action |
|---|---|
| `]]` | Next cell (next `# %%` marker) |
| `[[` | Previous cell |
| `]C` | Last cell in buffer |
| `[C` | First cell in buffer |

`]]` / `[[` are Vim's traditional section motions. Python has no sections, so
these are free. Using `]c` / `[c` would conflict with LazyVim's gitsigns
hunk navigation.

### Cell Textobjects (via `mini.ai`)

| Keys | Action |
|---|---|
| `aj` | Around cell (including `# %%` marker line) |
| `ij` | Inside cell (code only, marker excluded) |

Enables `dij`, `yaj`, `vij`, `caj`, and similar compound operations.

### Which-Key Integration

- Register `<localleader>j` as the group "jupyter".
- Register `<leader>` group entries so menu discoverability is preserved.
- Buffer-local `<localleader>?` command that `:echo`s the full binding table
  (serves as an in-editor cheatsheet).

## 4. Install & Windows Wiring

### `setup-dev-tools.ps1` additions

Added to the existing uv block (after `uv` is on PATH):

```powershell
& uv tool install jupytext
& uv tool install ipython
& uv tool install ipykernel --with ipython
```

Each install is followed by a `Wait-ForCommandInfo` verification against the
candidate paths under `$env:USERPROFILE\.local\bin`, matching the existing
pattern for `uv`, `fd`, and `rg`.

### `prereq_packages.sh` additions

The same three `uv tool install` commands, invoked during the Python layer
installation (`install_python_prereqs`). OS-guarded with the repo's existing
`$OS` detection (no effect on Windows; ps1 handles that independently).

### Windows Compatibility Notes

- `iron.nvim` uses Neovim's built-in `:terminal`. On Windows this hosts
  `cmd.exe` / `pwsh.exe` internally. Iron's recent fixes
  ("Fix five extra blank lines on Windows" Dec 2025, "fix is_windows bug"
  Jan 2026) confirm active Windows testing.
- `ipython.exe` on Windows needs no special terminal wrapper. Modern Windows
  10+ conhost handles ANSI escape sequences natively.
- `jupytext` handles CRLF line endings correctly when round-tripping `.ipynb`.
- The existing nvim config junction at `%LOCALAPPDATA%\nvim` (with copy
  fallback on network-backed home directories) means our new
  `plugins/jupyter.lua` lands where Neovim discovers it with no extra work.

### No Changes Needed

- `Brewfile.*` — jupytext/ipython are Python tools, installed via uv, not brew.
- `makefile` targets — no new make targets required.
- `ci/` Docker image — CI does not exercise Jupyter features.

## 5. Implementation Structure

Single new file: `nvim/lua/plugins/jupyter.lua`.

### Module Responsibilities

1. **Plugin spec for `iron.nvim`** — LazyVim-style return table entry.
2. **jupytext autocmd block** — `BufReadCmd` / `BufWriteCmd` for `*.ipynb`
   that shells out to `jupytext --to py:percent` and `jupytext --to ipynb`.
3. **Cell range helpers** — `get_current_cell_range()`,
   `get_cells_above()`, `get_cells_below()`. Pure functions on the current
   buffer.
4. **REPL glue** — thin wrappers that compute ranges via (3) and call
   `iron.core.send` with the result.
5. **Keymap setup** — buffer-local maps registered via a `FileType`
   autocmd for `python` and `ipynb`.
6. **mini.ai textobject registration** — `aj` / `ij` spec.
7. **mini.hipatterns registration** — highlight `^# %%.*$` lines.
8. **which-key group labels** — `<localleader>j` = "jupyter".

### File Size Expectation

~150 lines of Lua total. If the file grows past ~250 lines, split into
`plugins/jupyter.lua` (LazyVim specs) and `plugins/jupyter/cells.lua`
(helper logic).

### Configuration That Stays in `lang.lua`

- `opts.servers.pyright` (or whichever Python LSP LazyVim configures) — no
  change. Jupytext-converted Python is regular Python; the existing Python
  LSP stack applies.
- Treesitter `python` — already ensured by the `lazyvim.plugins.extras.lang.python` import.
- Conform `python = { "ruff_organize_imports", "ruff_format" }` — unchanged.
  Format-on-save will apply to the converted-view `.py` buffer, which
  round-trips back to `.ipynb` cleanly (jupytext preserves the `# %%`
  markers as cell boundaries).

## 6. Testing Strategy

### Headless Checks

Run after implementation in the worktree:

```bash
# Config parses
nvim --headless -c 'qall'

# iron.nvim loads without error
nvim --headless -c 'checkhealth iron' -c 'qall' 2>&1 | grep -iE "error|fail"

# Jupyter module loads
nvim --headless -c 'lua require("plugins.jupyter")' -c 'qall'

# Lazy plugin count sanity
nvim --headless -c 'lua print(require("lazy").stats().count)' -c 'qall'
```

These run identically on Linux (dev host) and via
`headless-config-validation` commands on Windows during manual verification.

### Manual Smoke Test

Run once on Linux, once on a Windows target:

1. Create a fixture notebook:
   ```bash
   cat > /tmp/smoke.py <<'EOF'
   # %%
   print("hi")
   # %%
   import math
   math.sqrt(9)
   EOF
   jupytext --to ipynb /tmp/smoke.py
   ```
2. `nvim /tmp/smoke.ipynb` — confirm Python view with `# %%` markers, not
   JSON.
3. `]]` and `[[` — confirm cell navigation.
4. `<localleader>jj` on cell 1 — confirm IPython split opens and `hi`
   appears.
5. `<localleader>jn` on cell 1 — confirm cursor advances to cell 2 after
   send.
6. `dij` in cell 2 — confirm marker stays, only inside-cell code deletes.
7. `:w` then reopen `/tmp/smoke.ipynb` in JupyterLab browser — confirm
   valid notebook.

### CI

Not added. Feature is Windows-primary and requires a live IPython kernel for
meaningful tests; Woodpecker CI does not host one.

### Out of Scope

- Automated tests for the REPL plumbing. Iron.nvim's own test suite covers
  that layer. We test only that *our* autocmds, keymaps, and module load
  cleanly, and that external dependencies install.
- Performance benchmarks. Expected overhead of jupytext conversion on open
  is well under 200ms for typical notebooks and is not measured here.

## 7. Documentation

- Update `docs/NEOVIM_KEYBINDINGS.md` with a new "Jupyter cells" section
  reflecting the bindings in §3. Preserve the existing Spacemacs-translation
  framing.
- No new top-level docs file. This spec is the design record; runtime
  discoverability is handled by which-key.

## 8. Risks & Open Questions

### Risks

1. **jupytext CLI version drift on Windows.** uv pins tool installs by
   default, but a future uv upgrade or manual `uv tool upgrade` could land a
   jupytext version that changes the `py:percent` format. Mitigation: the
   format has been stable for years; no action unless breakage is observed.
2. **Iron.nvim `:terminal` quirks on Windows conhost.** Iron's Dec 2025 fix
   indicates this is an active area. If blank-line or encoding issues
   recur, fall back to iron's "wezterm" or "external" backends. We stick with
   `:terminal` unless it empirically breaks.
3. **IPython startup cost on Windows.** ~1–2s first launch is typical; the
   "within 1s" success criterion in §1 applies to cell sends *after* the
   REPL is warm, not the initial open.

### Resolved Decisions

- Cell nav keys: `]]` / `[[` (Vim section motion, no LazyVim conflict).
- No plugin for ipynb conversion — DIY.
- REPL backend: iron.nvim (not slime, not molten).
- No inline plots; browser retains plot rendering.
- Install wiring: uv tool installs in both setup-dev-tools.ps1 and
  prereq_packages.sh.

## 9. Out of Scope (for this sub-spec)

Deferred to sibling sub-specs in the `feature/nvim-parity` pass:

- **Sub-spec 2**: AI assistants (`coder/claudecode.nvim` + Codex terminal
  toggle).
- **Sub-spec 3**: Git parity (neogit / diffview / gitsigns refinements).
- **Sub-spec 4**: Debug + polish (nvim-dap, visual-multi, spell, snippet
  verification).

Each lands its own design doc under `docs/superpowers/specs/`.
