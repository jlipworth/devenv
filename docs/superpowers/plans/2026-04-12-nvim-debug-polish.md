# Neovim Debug + Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the last parity gaps (debug, multi-cursor, spell, snippet port), without adding any make targets.

**Architecture:** Debug is three LazyVim extras (`dap.core`, `lang.python`, `lang.typescript`). Multi-cursor is a local plugin spec wrapping `mg979/vim-visual-multi` with its default `<C-n>` trigger. Spell is verification + doc only. Snippets are six LaTeX yasnippets ported to LuaSnip VSCode-style JSON.

**Tech Stack:** Neovim 0.12, LazyVim, nvim-dap family (via LazyVim extras), `mg979/vim-visual-multi`, LuaSnip + friendly-snippets (already in LazyVim base).

**Spec:** `docs/superpowers/specs/2026-04-12-nvim-debug-polish-design.md`

---

## Prerequisites

- [ ] **Confirm the test-app symlink exists**

```bash
ln -sfn /home/jlipworth/GNU_files/.worktrees/nvim-debug-polish/nvim ~/.config/nvim_parity_debug
ls -l ~/.config/nvim_parity_debug
```

Expected: symlink pointing at the worktree's `nvim/`. If it already exists pointing elsewhere, the `-f` in `-sfn` replaces it.

- [ ] **Record pre-sub-spec baseline plugin count**

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-debug-polish
NVIM_APPNAME=nvim_parity_debug nvim --headless \
  -c 'lua print(require("lazy").stats().count)' \
  -c 'qall' 2>&1 | tail -3
```

Record the number. Plan Task 8 compares against it.

- [ ] **Confirm `jq` and `curl` are installed (for Task 6)**

```bash
command -v jq curl
```

Expected: two paths. If either is missing, install via `$INSTALL_CMD` (brew or apt per repo conventions) before Task 6.

---

## File Structure

- Modify: `nvim/lua/config/lazy.lua` — add extras imports (Tasks 1, 2).
- New: `nvim/lua/plugins/visual-multi.lua` (Task 3).
- New: `nvim/lua/plugins/snippets.lua` (Task 5).
- New: `nvim/snippets/package.json` (Task 5).
- New: `nvim/snippets/latex.json` (Task 5).
- Modify: `docs/NEOVIM_KEYBINDINGS.md` — append Debug / Multi-cursor / Spell / Snippets sections (Task 7).

---

## Task 1: Add DAP core extra + verify Python DAP wiring

**Files:**
- Modify: `nvim/lua/config/lazy.lua`

- [ ] **Step 1: Read current lazy.lua**

```bash
cat /home/jlipworth/GNU_files/.worktrees/nvim-debug-polish/nvim/lua/config/lazy.lua
```

Expected shape:
```lua
spec = {
  { "LazyVim/LazyVim", import = "lazyvim.plugins" },
  { import = "lazyvim.plugins.extras.ai.claudecode" },
  { import = "plugins" },
},
```

If the shape differs (e.g., `lang.python` is already imported), adjust Step 2 accordingly. If `claudecode` is missing entirely, STOP — sub-spec 2 wasn't merged and this plan assumes it was.

- [ ] **Step 2: Insert `extras.dap.core` and `extras.lang.python` after claudecode**

Use Edit with `old_string`:
```
    { import = "lazyvim.plugins.extras.ai.claudecode" },
    { import = "plugins" },
```

and `new_string`:
```
    { import = "lazyvim.plugins.extras.ai.claudecode" },
    { import = "lazyvim.plugins.extras.dap.core" },
    { import = "lazyvim.plugins.extras.lang.python" },
    { import = "plugins" },
```

Preserve 4-space indentation. If `lang.python` is already imported (grep the file first), omit it from the new_string and keep only the `dap.core` addition.

- [ ] **Step 3: Headless parse check**

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-debug-polish
NVIM_APPNAME=nvim_parity_debug nvim --headless -c 'qall' 2>&1 | tail -5
```

Expected: empty output. If there's an error referencing `lang.python` already being imported, the precondition check in Step 2 was wrong — revert the `lang.python` line.

- [ ] **Step 4: Lazy sync to pull nvim-dap + deps**

```bash
NVIM_APPNAME=nvim_parity_debug nvim --headless "+Lazy! sync" +qa 2>&1 | tail -20
```

Expected: nvim-dap, nvim-dap-ui, nvim-dap-virtual-text, nvim-nio, mason-nvim-dap, nvim-dap-python, venv-selector.nvim appear in the install log. No errors.

- [ ] **Step 5: Module loads**

```bash
NVIM_APPNAME=nvim_parity_debug nvim --headless \
  -c 'lua require("dap"); require("dap-python"); print("OK")' \
  -c 'qall' 2>&1 | tail -3
```

Expected: `OK`. Anything else is BLOCKED.

- [ ] **Step 6: A representative DAP keymap is registered**

```bash
NVIM_APPNAME=nvim_parity_debug nvim --headless \
  -c 'lua for _, m in ipairs(vim.api.nvim_get_keymap("n")) do if m.lhs:match(" db$") or m.lhs == " db" then print("found: " .. m.lhs); break end end' \
  -c 'qall' 2>&1 | tail -3
```

Expected: a `found:` line. If blank, the keymap may be lazy; acceptable. Record the result.

- [ ] **Step 7: Commit**

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-debug-polish
git add nvim/lua/config/lazy.lua
git commit -m "Import LazyVim dap.core + lang.python extras for Python debugging"
```

---

## Task 2: Add JS/TS DAP via lang.typescript extra

**Files:**
- Modify: `nvim/lua/config/lazy.lua`

- [ ] **Step 1: Insert the typescript extra import**

Use Edit with `old_string`:
```
    { import = "lazyvim.plugins.extras.lang.python" },
    { import = "plugins" },
```

and `new_string`:
```
    { import = "lazyvim.plugins.extras.lang.python" },
    { import = "lazyvim.plugins.extras.lang.typescript" },
    { import = "plugins" },
```

- [ ] **Step 2: Headless parse**

```bash
NVIM_APPNAME=nvim_parity_debug nvim --headless -c 'qall' 2>&1 | tail -5
```

Expected: empty.

- [ ] **Step 3: Lazy sync**

```bash
NVIM_APPNAME=nvim_parity_debug nvim --headless "+Lazy! sync" +qa 2>&1 | tail -20
```

Expected: the ts LSP chain (vtsls extra + deps) installs. No errors.

- [ ] **Step 4: Confirm js-debug-adapter is queued for Mason**

```bash
NVIM_APPNAME=nvim_parity_debug nvim --headless \
  -c 'lua local ok, mc = pcall(require, "mason-nvim-dap.mappings.source"); print(ok and "mason-nvim-dap ok" or "missing")' \
  -c 'qall' 2>&1 | tail -3
```

Expected: `mason-nvim-dap ok`.

- [ ] **Step 5: Manually trigger Mason install of js-debug-adapter (may already be auto-installed)**

```bash
NVIM_APPNAME=nvim_parity_debug nvim --headless \
  -c 'MasonInstall js-debug-adapter debugpy' \
  -c 'qall' 2>&1 | tail -10
```

Expected: success messages or "already installed." Network flakes here are acceptable — flag in the task report but don't BLOCK; the smoke test catches true failure.

- [ ] **Step 6: Commit**

```bash
git add nvim/lua/config/lazy.lua
git commit -m "Import LazyVim lang.typescript extra for JS/TS debug adapter"
```

---

## Task 3: Add vim-visual-multi local spec

**Files:**
- New: `nvim/lua/plugins/visual-multi.lua`

- [ ] **Step 1: Check for pre-existing `<C-n>` normal-mode conflict**

```bash
NVIM_APPNAME=nvim_parity_debug nvim --headless \
  -c 'lua for _, m in ipairs(vim.api.nvim_get_keymap("n")) do if m.lhs == "<C-n>" or m.lhs == "\\x0e" then print("CLASH: " .. vim.inspect(m)) end end' \
  -c 'qall' 2>&1 | tail -5
```

Expected: empty (no clash) or one informational line. If a real clash prints (a user-installed plugin claims `<C-n>` normal-mode), record the source; we still proceed because VM's binding is the one we want.

- [ ] **Step 2: Create the plugin spec**

Write `nvim/lua/plugins/visual-multi.lua` with exactly this content:

```lua
-- Multi-cursor editing. See docs/superpowers/specs/2026-04-12-nvim-debug-polish-design.md
-- Plugin delta: +1 (vim-visual-multi).
-- Default <C-n> trigger: no conflict with LazyVim defaults (normal-mode
-- <C-n> is unbound; insert-mode <C-n> is cmp's "next item" and VM does
-- not claim insert-mode).

return {
  {
    "mg979/vim-visual-multi",
    branch = "master",
    keys = {
      { "<C-n>", mode = { "n", "v" }, desc = "Multi-cursor: select next match" },
      { "<C-Up>", mode = { "n" }, desc = "Multi-cursor: add cursor above" },
      { "<C-Down>", mode = { "n" }, desc = "Multi-cursor: add cursor below" },
    },
    init = function()
      -- Leave g:VM_maps at upstream defaults. If a future conflict
      -- surfaces, set a custom "Find Under" here.
    end,
  },
}
```

- [ ] **Step 3: Headless parse + install**

```bash
NVIM_APPNAME=nvim_parity_debug nvim --headless "+Lazy! sync" +qa 2>&1 | tail -10
```

Expected: vim-visual-multi appears in the install log. No errors.

- [ ] **Step 4: Confirm the plugin registers its autocommand group**

```bash
NVIM_APPNAME=nvim_parity_debug nvim --headless \
  -c 'edit /tmp/vm_smoke.txt' \
  -c 'normal! ifoo foo foo' \
  -c 'lua local hit = false; for _, m in ipairs(vim.api.nvim_get_keymap("n")) do if m.lhs == "<C-N>" or m.lhs == "<C-n>" then hit = true end end; print(hit and "VM-bound" or "VM-lazy")' \
  -c 'qall!' 2>&1 | tail -3
```

Expected: either `VM-bound` (plugin loaded eagerly) or `VM-lazy` (binding is in the `keys =` table and will load on first press). Both are acceptable.

- [ ] **Step 5: Confirm no insert-mode `<C-n>` regression**

```bash
NVIM_APPNAME=nvim_parity_debug nvim --headless \
  -c 'lua for _, m in ipairs(vim.api.nvim_get_keymap("i")) do if m.lhs == "<C-N>" or m.lhs == "<C-n>" then print("insert <C-n>: " .. (m.desc or "no desc")) end end' \
  -c 'qall' 2>&1 | tail -5
```

Expected: either nothing (cmp hasn't loaded yet) or a line describing cmp's "select next item." VM-related desc would be a conflict — if seen, BLOCK and investigate.

- [ ] **Step 6: Commit**

```bash
git add nvim/lua/plugins/visual-multi.lua
git commit -m "Add vim-visual-multi for multi-cursor editing (<C-n>)"
```

---

## Task 4: Verify spell check + doc prep

No code change in this task — pure verification. The doc append happens in Task 7 to keep all doc churn in one commit.

- [ ] **Step 1: Confirm LazyVim's default spell autocmd fires on markdown**

```bash
mkdir -p /tmp/spell_smoke
printf '# Some misspelt %s here\n' "w""rod" > /tmp/spell_smoke/test.md
NVIM_APPNAME=nvim_parity_debug nvim --headless \
  -c 'edit /tmp/spell_smoke/test.md' \
  -c 'lua print(vim.bo.spell, vim.bo.spelllang)' \
  -c 'qall' 2>&1 | tail -3
```

Expected: `true    en` (or `true    en_us`). If `false`, LazyVim's markdown autocmd didn't fire — check `:autocmd FileType markdown` in a real session and note for Task 7 doc wording.

- [ ] **Step 2: Test `:setlocal spell` works on arbitrary buffers**

```bash
NVIM_APPNAME=nvim_parity_debug nvim --headless \
  -c 'enew' \
  -c 'setlocal spell spelllang=en_us' \
  -c 'lua print(vim.wo.spell, vim.o.spelllang)' \
  -c 'qall' 2>&1 | tail -3
```

Expected: `true    en_us`.

- [ ] **Step 3: Confirm spell data path resolves**

```bash
NVIM_APPNAME=nvim_parity_debug nvim --headless \
  -c 'lua print(vim.fn.stdpath("data") .. "/site/spell/")' \
  -c 'qall' 2>&1 | tail -3
```

Expected: `/home/jlipworth/.local/share/nvim_parity_debug/site/spell/` (or equivalent on the test host).

- [ ] **Step 4: No commit for this task — verification only**

Record the output of Steps 1-3 in the task report. They inform the doc wording in Task 7.

---

## Task 5: Port LaTeX yasnippets to LuaSnip

**Files:**
- New: `nvim/lua/plugins/snippets.lua`
- New: `nvim/snippets/package.json`
- New: `nvim/snippets/latex.json`

- [ ] **Step 1: Confirm source yasnippets are exactly the six expected**

```bash
ls /home/jlipworth/GNU_files/.worktrees/nvim-debug-polish/snippets/latex-mode/
```

Expected: `align_star  equation_star  section_star  subsection_star  textit  underline`. If any additional files are present, STOP and re-scope — the spec assumed 6.

- [ ] **Step 2: Create `nvim/snippets/` directory**

```bash
mkdir -p /home/jlipworth/GNU_files/.worktrees/nvim-debug-polish/nvim/snippets
```

- [ ] **Step 3: Write `nvim/snippets/package.json`**

Exact content:

```json
{
  "name": "nvim-parity-snippets",
  "description": "Repo-managed snippets ported from snippets/ yasnippet sources.",
  "version": "1.0.0",
  "engines": { "vscode": "^1.11.0" },
  "contributes": {
    "snippets": [
      {
        "language": ["tex", "latex", "plaintex"],
        "path": "./latex.json"
      }
    ]
  }
}
```

- [ ] **Step 4: Write `nvim/snippets/latex.json`**

Exact content (note: `$1`, `$0` tabstops come through verbatim; `\\` is literal backslash in JSON):

```json
{
  "align*": {
    "prefix": "al*",
    "body": [
      "\\begin{align*}",
      "  $1",
      "\\end{align*}",
      "$0"
    ],
    "description": "LaTeX align* environment"
  },
  "equation*": {
    "prefix": "eq*",
    "body": [
      "\\begin{equation*}",
      "  $1",
      "\\end{equation*}",
      "$0"
    ],
    "description": "LaTeX equation* environment"
  },
  "section*": {
    "prefix": "secc",
    "body": [
      "\\section*{$1}",
      "$0"
    ],
    "description": "LaTeX unnumbered section"
  },
  "subsection*": {
    "prefix": "subb",
    "body": [
      "\\subsection*{$1}",
      "$0"
    ],
    "description": "LaTeX unnumbered subsection"
  },
  "textit": {
    "prefix": "i",
    "body": [
      "\\textit{$1}$0"
    ],
    "description": "LaTeX italic"
  },
  "underline": {
    "prefix": "u",
    "body": [
      "\\underline{$1}$0"
    ],
    "description": "LaTeX underline"
  }
}
```

- [ ] **Step 5: Write `nvim/lua/plugins/snippets.lua`**

Exact content:

```lua
-- LuaSnip: load repo-managed VSCode-style snippets from nvim/snippets/.
-- See docs/superpowers/specs/2026-04-12-nvim-debug-polish-design.md §5.
-- Plugin delta: 0 (LuaSnip is already in LazyVim base).

return {
  {
    "L3MON4D3/LuaSnip",
    config = function(_, opts)
      if opts then
        require("luasnip").setup(opts)
      end
      require("luasnip.loaders.from_vscode").lazy_load({
        paths = { vim.fn.stdpath("config") .. "/snippets" },
      })
    end,
  },
}
```

- [ ] **Step 6: Headless parse**

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-debug-polish
NVIM_APPNAME=nvim_parity_debug nvim --headless -c 'qall' 2>&1 | tail -5
```

Expected: empty.

- [ ] **Step 7: Verify snippets load**

```bash
NVIM_APPNAME=nvim_parity_debug nvim --headless \
  -c 'lua require("luasnip.loaders.from_vscode").lazy_load({ paths = { vim.fn.stdpath("config") .. "/snippets" } })' \
  -c 'lua print("tex:", vim.tbl_count(require("luasnip").get_snippets("tex") or {}))' \
  -c 'qall' 2>&1 | tail -3
```

Expected: `tex: N` where N ≥ 6. (friendly-snippets may contribute additional `tex` snippets.) If exactly 0, the loader path is wrong — verify `stdpath("config")` resolves to the nvim_parity_debug directory.

- [ ] **Step 8: Commit**

```bash
git add nvim/snippets/ nvim/lua/plugins/snippets.lua
git commit -m "Port 6 LaTeX yasnippets to LuaSnip VSCode JSON format"
```

---

## Task 7: Document Debug / Multi-cursor / Spell / Snippets

**Files:**
- Modify: `docs/NEOVIM_KEYBINDINGS.md`

- [ ] **Step 1: Inspect the doc's current tail**

```bash
tail -20 /home/jlipworth/GNU_files/.worktrees/nvim-debug-polish/docs/NEOVIM_KEYBINDINGS.md
```

Expected: ends with the Claude Code section's Spacemacs-translation table (from sub-spec 2).

- [ ] **Step 2: Append all four sections at the end of the file**

Append the following markdown verbatim (starts with a blank line; everything inside the code fence is the content to append, fences themselves are NOT part of the file):

```markdown

## Debug (nvim-dap)

Debugging is wired through LazyVim's `dap.core`, `lang.python`, and
`lang.typescript` extras. Adapters install automatically via Mason on
first use (`debugpy` for Python, `js-debug-adapter` for JS/TS). Run
`:MasonInstall debugpy js-debug-adapter` manually if the auto-install
fails or is skipped.

### Session (group `<leader>d` — "debug")

| Keys | Action |
|---|---|
| `<leader>db` | Toggle breakpoint |
| `<leader>dB` | Breakpoint with condition |
| `<leader>dc` | Run / Continue |
| `<leader>dC` | Run to cursor |
| `<leader>da` | Run with args (prompts) |
| `<leader>dl` | Run last |
| `<leader>dt` | Terminate |
| `<leader>dr` | Toggle REPL |
| `<leader>ds` | Session info |

### Stepping

| Keys | Action |
|---|---|
| `<leader>di` | Step into |
| `<leader>dO` | Step over |
| `<leader>do` | Step out |
| `<leader>dP` | Pause |
| `<leader>dj` / `<leader>dk` | Frame down / up |
| `<leader>dg` | Go to line (no execute) |

### Inspection

| Keys | Mode | Action |
|---|---|---|
| `<leader>du` | normal | Toggle DAP UI |
| `<leader>dw` | normal | Hover widget |
| `<leader>de` | normal / visual | Evaluate expression |

### Python-specific

| Keys | Action |
|---|---|
| `<leader>dPt` | Debug test method under cursor |
| `<leader>dPc` | Debug test class under cursor |

### Spacemacs translation

| Spacemacs | Neovim here |
|---|---|
| `SPC d d` (run / continue) | `<leader>dc` |
| `SPC d b` (toggle breakpoint) | `<leader>db` |
| `SPC d i` (step into) | `<leader>di` |
| `SPC d o` (step over) | `<leader>dO` |
| `SPC d r` (REPL) | `<leader>dr` |

## Multi-cursor (vim-visual-multi)

| Keys | Mode | Action |
|---|---|---|
| `<C-n>` | normal / visual | Start session; select word / range under cursor. Press again to add next match. |
| `<C-Up>` / `<C-Down>` | normal | Add a cursor above / below |
| `<S-Left>` / `<S-Right>` | VM | Extend all cursors' selection |
| `n` / `N` | VM | Next / previous match |
| `q` | VM | Skip current match, jump to next |
| `Q` | VM | Remove the current cursor |
| `<Esc>` | VM | Exit multi-cursor mode |

See `:help visual-multi` for the full cheatsheet. The upstream project
is feature-complete (last commit 2024-09-01).

## Spell check

LazyVim sets `spell` automatically on `gitcommit` and `markdown`
filetypes. For any other buffer:

```
:setlocal spell spelllang=en_us
```

Neovim downloads `.spl` files on demand to
`~/.local/share/nvim/site/spell/`. If the first prompt was declined,
re-run `:set spell` in an interactive session to re-trigger it.

| Keys | Action |
|---|---|
| `]s` / `[s` | Next / previous misspelling |
| `z=` | Suggest replacements |
| `zg` / `zw` | Mark word good / wrong (persists in spellfile) |

## Snippets (LuaSnip)

LuaSnip ships with LazyVim. This repo adds VSCode-style snippets in
`nvim/snippets/`, ported from the Yasnippet sources under `snippets/`
so the same triggers work in both Spacemacs and Neovim.

Current ported set (filetype `tex`):

| Trigger | Expansion |
|---|---|
| `al*` | `\begin{align*} ... \end{align*}` |
| `eq*` | `\begin{equation*} ... \end{equation*}` |
| `secc` | `\section*{...}` |
| `subb` | `\subsection*{...}` |
| `i` | `\textit{...}` |
| `u` | `\underline{...}` |

Type the trigger in insert mode and press `<Tab>` to expand (default
LazyVim / LuaSnip expansion key). `friendly-snippets` provides
additional `tex` snippets alongside these.
```

(The triple-backtick fence immediately above delimits the content for
the implementer — do NOT include it in the file.)

- [ ] **Step 3: Verify the append landed**

```bash
tail -60 /home/jlipworth/GNU_files/.worktrees/nvim-debug-polish/docs/NEOVIM_KEYBINDINGS.md
```

Expected: the new four sections at the bottom, "Snippets (LuaSnip)" last.

- [ ] **Step 4: Commit**

```bash
git add docs/NEOVIM_KEYBINDINGS.md
git commit -m "Document debug, multi-cursor, spell, and snippet bindings"
```

---

## Task 8: Full validation pass

No code changes — run the full suite and record results.

- [ ] **Step 1: Headless parse**

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-debug-polish
NVIM_APPNAME=nvim_parity_debug NVIM_DISABLE_AUTO_INSTALLS=1 nvim --headless -c 'qall' 2>&1 | tail -5
```

Expected: empty.

- [ ] **Step 2: Plugin count delta**

```bash
NVIM_APPNAME=nvim_parity_debug NVIM_DISABLE_AUTO_INSTALLS=1 nvim --headless \
  -c 'lua print(require("lazy").stats().count)' \
  -c 'qall' 2>&1 | tail -3
```

Expected: pre-sub-spec count + 8 to + 12. Record the number. Any larger delta = investigate (an extra's transitive dep changed); any smaller = a plugin didn't install.

- [ ] **Step 3: DAP loads**

```bash
NVIM_APPNAME=nvim_parity_debug NVIM_DISABLE_AUTO_INSTALLS=1 nvim --headless \
  -c 'lua require("dap"); require("dap-python"); require("dapui"); print("OK")' \
  -c 'qall' 2>&1 | tail -3
```

Expected: `OK`.

- [ ] **Step 4: Visual-multi baseline**

```bash
NVIM_APPNAME=nvim_parity_debug NVIM_DISABLE_AUTO_INSTALLS=1 nvim --headless \
  -c 'let g:VM_mouse_mappings = 0' \
  -c 'qall' 2>&1 | tail -3
```

Expected: empty.

- [ ] **Step 5: Snippets load**

```bash
tmpdir="$(mktemp -d)" && touch "$tmpdir/x.tex" && \
NVIM_APPNAME=nvim_parity_debug NVIM_DISABLE_AUTO_INSTALLS=1 nvim --headless \
  -c "edit $tmpdir/x.tex" \
  -c 'lua vim.wait(200, function() return #require("luasnip").get_snippets("tex") > 0 end)' \
  -c 'lua print(vim.tbl_count(require("luasnip").get_snippets("tex") or {}))' \
  -c 'qall' 2>&1 | tail -3 ; rm -rf "$tmpdir"
```

Expected: ≥ 6. The `lazy_load` call in `snippets.lua` is async and only
populates snippets once a `tex`/`latex`/`plaintex` buffer is actually
loaded, so validate in that context — a bare headless session will
return 0 even when the wiring is correct.

- [ ] **Step 6: Jupyter regression**

```bash
bash tests/nvim/run_nvim_tests.sh 2>&1 | tail -5
```

Expected: `ALL TESTS PASSED`.

- [ ] **Step 8: Claude Code regression**

```bash
NVIM_APPNAME=nvim_parity_debug NVIM_DISABLE_AUTO_INSTALLS=1 nvim --headless \
  -c 'lua require("claudecode"); print("OK")' \
  -c 'qall' 2>&1 | tail -3
```

Expected: `OK`.

- [ ] **Step 9: Manual smoke test (HUMAN-RUN)**

Not automated. Document in the task report; the implementer hands this off to the user:

1. Start `NVIM_APPNAME=nvim_parity_debug nvim /tmp/debug_smoke.py` with a trivial Python file containing a `print("hi")`. Press `<leader>db` to set a breakpoint, `<leader>dc` to launch — DAP-UI should open.
2. Open a trivial `.ts` file. Press `<leader>dc` and pick the node launch config.
3. In any buffer with the word "foo" repeated, press `<C-n>` — a VM session should start.
4. Open a `.md` file with a misspelling — it should highlight. Press `z=`.
5. Open a `.tex` file, type `secc<Tab>` in insert mode — it should expand to `\section*{...}`.

- [ ] **Step 10: If any headless step failed, commit fixes now**

```bash
# Only if fixes were made:
git add -A
git diff --cached --stat
git commit -m "Fixups from debug+polish validation"
```

Skip if no fixes were needed.

---

## Self-Review

### Spec coverage

Mapping each spec requirement to a task:

- §1 Success Criteria 1 (headless loads cleanly, plugin count bounded) → Task 8 Steps 1-2.
- §1 Success Criteria 2 (`<leader>db`, `<leader>dc`, DAP-UI, `<leader>dPt`) → Task 1 Steps 4-6, Task 8 Step 3, Task 8 Step 9 (manual).
- §1 Success Criteria 3 (`<leader>dc` on `.ts` launches js-debug-adapter) → Task 2 Steps 3-5, Task 8 Step 9 (manual).
- §1 Success Criteria 4 (`<C-n>` starts VM, `<Esc>` exits) → Task 3 Steps 3-5, Task 8 Step 9 (manual).
- §1 Success Criteria 5 (spell on `.md`, dictionary docs) → Task 4 Steps 1-3, Task 7 Step 2.
- §1 Success Criteria 6 (≥6 tex snippets) → Task 5 Step 7, Task 8 Step 5.
- §1 Success Criteria 7 (no regression) → Task 8 Steps 6-7.
- §2 Plugin stack (dap extras, visual-multi, LuaSnip loader) → Task 1 Step 2, Task 2 Step 1, Task 3 Step 2, Task 5 Step 5.
- §3 Keymap layout (LazyVim defaults, VM defaults) → Tasks 1-3 accept defaults; Task 7 documents them.
- §4 Spell check (no plugin, document only) → Task 4 + Task 7 Step 2.
- §5 Snippet parity (6 LaTeX yasnippets ported to VSCode JSON) → Task 5.
- §7 Implementation structure (file list) → matches Task 1 / 2 / 3 / 5 / 7 file lists.
- §8 Testing strategy (headless parse, DAP loads, VM loads, snippets load, regression guards) → Task 8.
- §9 Risks (extra.lang.python double-import, Mason flakes, `<C-n>` clash, 19-mo VM, single-char triggers) → mitigations land in Task 1 Step 1 (pre-inspect), Task 2 Step 5 (manual Mason), Task 3 Steps 1/5 (conflict check).

No spec requirement is unclaimed.

### Placeholder scan

- No TBD / TODO / FIXME / "similar to" / "appropriate error handling" / vague test descriptions.
- Every code block is complete and paste-able.
- Every shell command has an explicit Expected line.

### Type consistency

- Extras-import strings (`lazyvim.plugins.extras.dap.core`, `lazyvim.plugins.extras.lang.python`, `lazyvim.plugins.extras.lang.typescript`) appear identically in Tasks 1-2 and spec §7.
- Snippet filetype (`tex`) appears identically in Task 5 Step 3 (package.json), Task 5 Step 7 (validation), Task 7 Step 2 (docs), spec §5.
- Plugin-count delta expectation (+8 to +12) in Task 8 Step 2 matches spec §2.
- Keymap strings (`<leader>db`, `<leader>dc`, `<leader>dPt`, `<C-n>`, etc.) are identical between Task 7 docs and spec §3.

No drift detected.

### Commit-per-task discipline

Tasks 1, 2, 3, 5, 7 each end with a commit. Task 4 is pure verification (no commit). Task 8 commits only if fixups are needed.
