# Neovim AI Assistants (Claude Code) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire Claude Code into Neovim via LazyVim's pre-baked `claudecode` extra, with no custom plugin spec or keymap overrides.

**Architecture:** A single LazyVim extra import in `nvim/lua/config/lazy.lua` pulls in `coder/claudecode.nvim` with its default `<leader>a*` keymap layout. Claude Code CLI install is already handled by both OS install scripts; no wiring needed there. The nvim↔CLI bridge is a localhost WebSocket auto-discovered by the CLI.

**Tech Stack:** Neovim 0.12, LazyVim distribution, `coder/claudecode.nvim` (via LazyVim extra), Claude Code CLI (npm on Windows, native installer on Unix — already installed by existing scripts).

**Spec:** `docs/superpowers/specs/2026-04-12-nvim-ai-assistants-design.md`

---

## File Structure

- Modify: `nvim/lua/config/lazy.lua` — one-line import added to `spec` table
- Modify: `docs/NEOVIM_KEYBINDINGS.md` — append a "Claude Code" section
- (No new files, no `nvim/lua/plugins/` spec file, no install-script changes)

---

## Task 1: Add the LazyVim claudecode extra import

**Files:**
- Modify: `nvim/lua/config/lazy.lua`

- [ ] **Step 1: Read the current file**

```bash
cat /home/jlipworth/GNU_files/.worktrees/nvim-parity/nvim/lua/config/lazy.lua
```

Expected: a `require("lazy").setup({ ... })` block whose `spec` table contains:
```lua
spec = {
  { "LazyVim/LazyVim", import = "lazyvim.plugins" },
  { import = "plugins" },
},
```

If the file has drifted from this shape, STOP and escalate — later steps assume this structure.

- [ ] **Step 2: Insert the claudecode extra import between the two existing spec entries**

Use Edit tool with `old_string`:
```
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    { import = "plugins" },
```

and `new_string`:
```
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    { import = "lazyvim.plugins.extras.ai.claudecode" },
    { import = "plugins" },
```

Rationale for this placement: LazyVim extras must come after `lazyvim.plugins` (so they can override LazyVim defaults) and before the local `plugins` dir (so local `nvim/lua/plugins/*` can override extras if ever needed). Preserve indentation (4 spaces).

- [ ] **Step 3: Headless parse check**

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-parity
NVIM_APPNAME=nvim_parity_test nvim --headless -c 'qall' 2>&1 | tail -5
```

Expected: empty output, exit 0. Any stderr = config error. If there is an error, do NOT proceed; report BLOCKED and include the stderr.

- [ ] **Step 4: Lazy sync to install claudecode.nvim**

```bash
NVIM_APPNAME=nvim_parity_test nvim --headless "+Lazy! sync" +qa 2>&1 | tail -10
```

Expected: no errors. You should see claudecode.nvim (and nui.nvim if not already installed) appear in the update log.

- [ ] **Step 5: Verify the claudecode Lua module loads**

```bash
NVIM_APPNAME=nvim_parity_test nvim --headless \
  -c 'lua require("claudecode"); print("OK")' \
  -c 'qall' 2>&1 | tail -3
```

Expected: `OK`. Anything else (especially "module not found" or a stack trace) means the plugin did not install correctly — report BLOCKED with the stderr.

- [ ] **Step 6: Confirm the `:ClaudeCode` command exists**

```bash
NVIM_APPNAME=nvim_parity_test nvim --headless \
  -c 'lua print(vim.fn.exists(":ClaudeCode"))' \
  -c 'qall' 2>&1 | tail -3
```

Expected: `2` (Neovim's return value for "command exists"). `0` means the plugin loaded but did not register its user command — report BLOCKED.

- [ ] **Step 7: Verify a representative default keymap is registered**

```bash
NVIM_APPNAME=nvim_parity_test nvim --headless \
  -c 'lua for _, m in ipairs(vim.api.nvim_get_keymap("n")) do if m.lhs:match("<leader>ac") or m.lhs:match("\\\\ac") or m.lhs == " ac" then print("found: " .. m.lhs); break end end' \
  -c 'qall' 2>&1 | tail -3
```

Expected: a `found: ...` line. The exact LHS rendering varies because `<leader>` resolves to the user's actual leader (space); as long as one line prints, the mapping is in. If nothing prints, lazy.nvim may have registered the binding lazily on first use — this is acceptable. Record the outcome either way; it is informational, not a blocker.

- [ ] **Step 8: Commit**

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-parity
git add nvim/lua/config/lazy.lua
git commit -m "Import LazyVim claudecode extra for Claude Code integration"
```

---

## Task 2: Document the Claude Code bindings

**Files:**
- Modify: `docs/NEOVIM_KEYBINDINGS.md`

- [ ] **Step 1: Inspect the current doc structure**

```bash
head -20 /home/jlipworth/GNU_files/.worktrees/nvim-parity/docs/NEOVIM_KEYBINDINGS.md
tail -15 /home/jlipworth/GNU_files/.worktrees/nvim-parity/docs/NEOVIM_KEYBINDINGS.md
```

Expected: a markdown doc. The previous sub-spec (Jupyter) appended its section at the end; do the same here for consistency.

- [ ] **Step 2: Append the Claude Code section at the very end of the file**

Append this markdown content exactly (starts with a blank line; content continues through the Spacemacs-translation paragraph):

```markdown

## Claude Code

`<leader>ac` toggles a vertical split running the `claude` CLI inside
Neovim. The split and the CLI discover each other over a localhost
WebSocket — no further configuration needed. The Claude Code CLI must
already be on PATH (both `setup-dev-tools.ps1` and `prereq_packages.sh`
install it as part of the base setup).

### Session (group `<leader>a` — "ai")

| Keys | Action |
|---|---|
| `<leader>ac` | Toggle Claude Code split |
| `<leader>af` | Focus Claude Code split |
| `<leader>ar` | Resume last Claude session |
| `<leader>aC` | Continue current Claude session |
| `<leader>ab` | Add current buffer to Claude context |

### Sending code

| Keys | Mode | Action |
|---|---|---|
| `<leader>as` | visual | Send visual selection to Claude |
| `<leader>as` | normal (in NvimTree / neo-tree / oil) | Add the file under cursor to Claude |

### Diff review

| Keys | Action |
|---|---|
| `<leader>aa` | Accept Claude-proposed diff |
| `<leader>ad` | Deny Claude-proposed diff |

### Spacemacs translation

| Spacemacs | Neovim here |
|---|---|
| *(no direct equivalent)* | `<leader>ac` toggles Claude Code session |
| `SPC a *` (apps/assistants prefix) | `<leader>a *` — same mnemonic, same intent |
```

Do NOT include the triple-backtick fences above in the file — they are delimiting the markdown content for the implementer. Append the content BETWEEN the fences (starting with the blank line and ending with the final table row).

- [ ] **Step 3: Verify the append looks right**

```bash
tail -35 /home/jlipworth/GNU_files/.worktrees/nvim-parity/docs/NEOVIM_KEYBINDINGS.md
```

Expected: the new "Claude Code" section appears at the bottom with all three tables and the Spacemacs-translation table.

- [ ] **Step 4: Commit**

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-parity
git add docs/NEOVIM_KEYBINDINGS.md
git commit -m "Document Claude Code bindings in NEOVIM_KEYBINDINGS.md"
```

---

## Task 3: Full validation pass

No code changes in this task — just run the full headless validation suite and record results. Any failure here is a blocker; go back and fix.

- [ ] **Step 1: Full config parse**

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-parity
NVIM_APPNAME=nvim_parity_test nvim --headless -c 'qall' 2>&1 | tail -5
```

Expected: empty output.

- [ ] **Step 2: Plugin count is stable and non-degenerate**

```bash
NVIM_APPNAME=nvim_parity_test nvim --headless \
  -c 'lua print(require("lazy").stats().count)' \
  -c 'qall' 2>&1 | tail -3
```

Expected: a number ≥ 48 (the pre-Task-1 count was 47; claudecode.nvim adds at least 1). Record the number. If the count went DOWN compared to master, something dropped — report BLOCKED.

- [ ] **Step 3: Re-run the Jupyter test suite to confirm no regression**

```bash
bash tests/nvim/run_nvim_tests.sh 2>&1 | tail -5
```

Expected: `ALL TESTS PASSED` for both cells and repl specs. Sub-spec 2 should not affect sub-spec 1 in any way; this is a regression guard only.

- [ ] **Step 4: `checkhealth claudecode` smoke**

```bash
NVIM_APPNAME=nvim_parity_test nvim --headless \
  -c 'checkhealth claudecode' \
  -c 'qall' 2>&1 | grep -iE "^\s*(error|fail)" | head
```

Expected: no output. A missing `claude` CLI would typically surface here as an error; if you see one and `which claude` confirms the CLI is absent on the test host, that is a host-environment issue, not a plan failure — note it in the report but do not mark BLOCKED unless the CLI is genuinely missing from the install scripts' output paths.

- [ ] **Step 5: Manual smoke test (HUMAN-RUN, not automated)**

Document this in the report; do NOT attempt to run it headlessly — it requires a real terminal and a Claude Code login. The implementer's job is to confirm the headless checks pass and leave these steps as follow-up for the user:

1. Start nvim against this config: `NVIM_APPNAME=nvim_parity_test nvim`.
2. Hit `<leader>ac` — a vertical split should open running `claude`.
3. Open a code buffer. Visual-select a few lines. Hit `<leader>as`. The selection should arrive in the Claude split as context.
4. Ask Claude to propose a trivial edit. When it generates a diff, hit `<leader>aa` to accept or `<leader>ad` to deny. Confirm the buffer updates (or does not update) accordingly.
5. Hit `<leader>af` to refocus the Claude split from a code buffer.

- [ ] **Step 6: If any headless step failed, commit fix(es) now**

```bash
# Only if fixes were made:
git add -A
git diff --cached --stat
git commit -m "Fixups from AI-assistants validation"
```

(Skip entirely if no fixes were needed.)

---

## Self-Review

### Spec coverage

Mapping each spec requirement to a task:

- §1 Goal (wire Claude Code via LazyVim extra, both OS's) → Task 1. Install scripts already done upstream, no new task needed.
- §1 Success Criteria 1 (`<leader>ac` opens split) → Task 3 Step 5 (manual smoke).
- §1 Success Criteria 2 (`<leader>as` visual sends selection) → Task 3 Step 5.
- §1 Success Criteria 3 (`<leader>aa`/`<leader>ad` diff review) → Task 3 Step 5.
- §1 Success Criteria 4 (works on Windows) → verified out-of-band by the user on the Windows target.
- §1 Success Criteria 5 (no regression on Jupyter bindings) → Task 3 Step 3.
- §2 Plugin stack (LazyVim extra import) → Task 1 Step 2.
- §3 Keymap layout (no overrides) → documented in Task 2; enforcement is just "don't add overrides," handled by the fact that Task 1 only adds an import.
- §4 Install wiring → N/A, already handled.
- §5 Implementation structure (single import line, no new files) → Task 1 file list.
- §6 Testing (headless parse, module load, command registered) → Task 1 Steps 3–7, Task 3 Steps 1–4.
- §7 Documentation → Task 2.
- §9 Out of scope (git parity, debug/polish) → explicitly not addressed here.

No spec requirement is unclaimed.

### Placeholder scan

- No TBD / TODO / FIXME / "similar to" / "appropriate error handling" / vague test descriptions.
- Every code block is complete and directly paste-able.
- Every shell command has an explicit Expected output.

### Type consistency

- The spec import string `"lazyvim.plugins.extras.ai.claudecode"` appears in both Task 1 Step 2 (the edit) and §5 of the spec. Spelling matches exactly.
- The keymap names (`ClaudeCode`, `<leader>ac`, `<leader>as`, `<leader>aa`, `<leader>ad`, `<leader>af`, `<leader>ab`, `<leader>aC`, `<leader>ar`) are identical between the spec, Task 1 verification commands, and the Task 2 documentation append.
- Plugin count expectation (≥ 48) in Task 3 Step 2 is consistent with the "47 plugins on master" baseline recorded during sub-spec 1 validation.

No drift detected.
