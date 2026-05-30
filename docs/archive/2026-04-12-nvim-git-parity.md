# Neovim Git Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring Neovim to rough parity with Spacemacs' git workflow by wiring Neogit (Magit analogue), Diffview (side-by-side diff viewer), and Octo (GitHub issues/PRs) into the LazyVim config with minimal customization and no gitsigns overrides.

**Architecture:** One LazyVim extra import (`lazyvim.plugins.extras.util.octo`) plus one local plugin spec file (`nvim/lua/plugins/git.lua`) adding Neogit, Diffview, and octo-keymap collision fixes. One winget `gh` install line added to `setup-dev-tools.ps1` (Linux/macOS already install `gh` via `Brewfile.git`). Docs appended to `docs/NEOVIM_KEYBINDINGS.md`.

**Tech Stack:** Neovim 0.12, LazyVim distribution, `NeogitOrg/neogit`, `sindrets/diffview.nvim`, `pwntester/octo.nvim` (via LazyVim extra), `gh` CLI (brew on Unix, winget on Windows).

**Spec:** `docs/superpowers/specs/2026-04-12-nvim-git-parity-design.md`

---

## Prerequisites

Before Task 1 Step 3, ensure the headless-test appname symlink exists:

```bash
ln -sfn /home/jlipworth/GNU_files/.worktrees/nvim-git-parity/nvim ~/.config/nvim_parity_git
```

Expected: symlink exists (idempotent; no output if already set).

---

## File Structure

- Modify: `nvim/lua/config/lazy.lua` — one-line extra import added
- Create: `nvim/lua/plugins/git.lua` — neogit + diffview spec + octo keymap fixes
- Modify: `setup-dev-tools.ps1` — add winget `gh` install block
- Modify: `docs/NEOVIM_KEYBINDINGS.md` — append "Git" section

---

## Task 1: Add the LazyVim octo extra import

**Files:**
- Modify: `nvim/lua/config/lazy.lua`

- [ ] **Step 1: Read the current file**

```bash
cat /home/jlipworth/GNU_files/.worktrees/nvim-git-parity/nvim/lua/config/lazy.lua
```

Expected: a `require("lazy").setup({ ... })` block whose `spec` table contains:
```lua
spec = {
  { "LazyVim/LazyVim", import = "lazyvim.plugins" },
  { import = "lazyvim.plugins.extras.ai.claudecode" },
  { import = "plugins" },
},
```

If the file has drifted from this shape, STOP and escalate — later steps assume this structure.

- [ ] **Step 2: Insert the octo extra import after the claudecode extra**

Use Edit tool with `old_string`:
```
    { import = "lazyvim.plugins.extras.ai.claudecode" },
    { import = "plugins" },
```

and `new_string`:
```
    { import = "lazyvim.plugins.extras.ai.claudecode" },
    { import = "lazyvim.plugins.extras.util.octo" },
    { import = "plugins" },
```

Rationale: LazyVim extras are applied in order; keep the local `plugins` import LAST so `nvim/lua/plugins/git.lua` can override any keymap the octo extra sets (needed for the `gr` / `gP` collision fixes). Preserve indentation (4 spaces).

- [ ] **Step 3: Headless parse check**

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-git-parity
NVIM_APPNAME=nvim_parity_git nvim --headless -c 'qall' 2>&1 | tail -5
```

Expected: empty output, exit 0. Any stderr = config error. If there is an error, do NOT proceed; report BLOCKED and include the stderr.

- [ ] **Step 4: Commit**

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-git-parity
git add nvim/lua/config/lazy.lua
git commit -m "Import LazyVim octo extra for GitHub issues/PRs in Neovim"
```

---

## Task 2: Create the neogit + diffview + octo-overrides spec

**Files:**
- Create: `nvim/lua/plugins/git.lua`

- [ ] **Step 1: Confirm no file at the target path**

```bash
ls /home/jlipworth/GNU_files/.worktrees/nvim-git-parity/nvim/lua/plugins/git.lua 2>&1
```

Expected: `No such file or directory`. If the file exists, STOP and escalate — the plan assumes a clean create.

- [ ] **Step 2: Write the spec file**

Create `nvim/lua/plugins/git.lua` with exactly this content:

```lua
-- Git parity: Magit-style Neogit + Diffview + Octo (GitHub issues/PRs).
-- See docs/superpowers/specs/2026-04-12-nvim-git-parity-design.md.
-- Plugin delta: +3 (neogit, diffview, octo via extra). gitsigns stays on
-- LazyVim defaults with no customization here.

return {
  -- Magit-style git UI
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim", -- inline diff popups inside Neogit
    },
    cmd = { "Neogit" },
    keys = {
      { "<leader>gg", function() require("neogit").open() end, desc = "Neogit" },
      { "<leader>gc", function() require("neogit").open({ "commit" }) end, desc = "Neogit commit" },
      { "<leader>gl", function() require("neogit").open({ "log" }) end, desc = "Neogit log" },
      { "<leader>gr", function() require("neogit").open({ "pull" }) end, desc = "Neogit pull" },
      -- gP (push) is registered in the octo override spec below, because we
      -- must `false` octo's <leader>gP before binding our own.
    },
    opts = {
      integrations = { diffview = true, telescope = true },
      disable_commit_confirmation = false,
      graph_style = "unicode",
    },
  },

  -- Side-by-side and merge-conflict diff viewer
  {
    "sindrets/diffview.nvim",
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewFileHistory",
      "DiffviewRefresh",
      "DiffviewToggleFiles",
    },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diffview (working tree)" },
      { "<leader>gD", "<cmd>DiffviewOpen origin/HEAD...HEAD<cr>", desc = "Diffview (vs origin/HEAD)" },
      { "<leader>gF", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview file history" },
      { "<leader>gx", "<cmd>DiffviewClose<cr>", desc = "Diffview close" },
    },
  },

  -- Octo keymap fixups: relocate collisions with Neogit's pull/push bindings.
  {
    "pwntester/octo.nvim",
    keys = {
      { "<leader>gr", false }, -- was "List Repos (Octo)" in octo extra
      { "<leader>gP", false }, -- was "Search PRs (Octo)" in octo extra
      { "<leader>gR", "<cmd>Octo repo list<CR>", desc = "List Repos (Octo)" },
      -- Re-register Neogit's push on <leader>gP:
      { "<leader>gP", function() require("neogit").open({ "push" }) end, desc = "Neogit push" },
    },
  },
}
```

- [ ] **Step 3: Headless parse check**

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-git-parity
NVIM_APPNAME=nvim_parity_git nvim --headless -c 'qall' 2>&1 | tail -5
```

Expected: empty output, exit 0. Any stderr = config error. If there is an error, do NOT proceed; report BLOCKED and include the stderr.

- [ ] **Step 4: Lazy sync to install plugins**

```bash
NVIM_APPNAME=nvim_parity_git nvim --headless "+Lazy! sync" +qa 2>&1 | tail -15
```

Expected: no errors. You should see `neogit`, `diffview.nvim`, and `octo.nvim` appear in the update log (plus `plenary.nvim` if not already installed).

- [ ] **Step 5: Verify each Lua module loads**

```bash
NVIM_APPNAME=nvim_parity_git nvim --headless \
  -c 'lua require("neogit"); print("NEOGIT OK")' \
  -c 'qall' 2>&1 | tail -3

NVIM_APPNAME=nvim_parity_git nvim --headless \
  -c 'lua require("diffview"); print("DIFFVIEW OK")' \
  -c 'qall' 2>&1 | tail -3

NVIM_APPNAME=nvim_parity_git nvim --headless \
  -c 'lua require("octo"); print("OCTO OK")' \
  -c 'qall' 2>&1 | tail -3
```

Expected: each prints its respective `... OK` line. Any "module not found" or stack trace means the plugin did not install or a dependency is missing — report BLOCKED with the stderr.

- [ ] **Step 6: Confirm user commands exist**

```bash
NVIM_APPNAME=nvim_parity_git nvim --headless \
  -c 'lua print(vim.fn.exists(":Neogit"), vim.fn.exists(":DiffviewOpen"), vim.fn.exists(":Octo"))' \
  -c 'qall' 2>&1 | tail -3
```

Expected: `2\t2\t2` (three 2s, space- or tab-separated). `0` for any of the three means that plugin's command-registration did not fire — report BLOCKED.

- [ ] **Step 7: Verify <leader>gg resolves to Neogit, not Snacks.lazygit**

```bash
NVIM_APPNAME=nvim_parity_git nvim --headless \
  -c 'lua local k = vim.fn.maparg(" gg", "n", false, true); print(vim.inspect({rhs = k.rhs, desc = k.desc, callback = k.callback ~= nil}))' \
  -c 'qall' 2>&1 | tail -10
```

Expected: the output's `desc` is `"Neogit"` OR the `callback` is `true` with no mention of "lazygit" in `rhs`. If the desc says "Lazygit (Root Dir)", lazy.nvim applied the config/keymaps after our spec — report BLOCKED and investigate the load order.

- [ ] **Step 8: Commit**

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-git-parity
git add nvim/lua/plugins/git.lua
git commit -m "Add neogit + diffview + octo keymap overrides"
```

---

## Task 3: Add `gh` CLI install to the Windows setup script

**Files:**
- Modify: `setup-dev-tools.ps1`

- [ ] **Step 1: Locate the right install block**

```bash
grep -nE "Test-CommandExists|winget install" /home/jlipworth/GNU_files/.worktrees/nvim-git-parity/setup-dev-tools.ps1 | head -30
```

Expected: multiple lines showing the existing `winget install` pattern used for Git-for-Windows, lazygit, and other core tools. Pick the block that installs core tools in the "Pre-flight" / "Core tools" area (roughly lines 400–460). If no clear block exists, insert between the Git install and the Neovim install blocks.

- [ ] **Step 2: Read ~40 lines around the chosen insertion point**

```bash
sed -n '420,470p' /home/jlipworth/GNU_files/.worktrees/nvim-git-parity/setup-dev-tools.ps1
```

Expected: a clear `if (-not (Test-CommandExists "git"))` or similar pattern with `winget install --id ... -e --accept-source-agreements --accept-package-agreements` and `Refresh-SessionPath` afterwards. If the existing blocks differ in shape, MATCH that shape exactly in your insertion.

- [ ] **Step 3: Insert the `gh` install block**

Use Edit tool with `old_string` being a unique anchor (the line immediately before the chosen insertion point, plus the line after, to identify the location) and `new_string` being the same plus the new block.

Example (adjust to actual surrounding code):

```powershell
# --- GitHub CLI (required by octo.nvim for GitHub issue/PR browsing) ---
if (-not (Test-CommandExists "gh")) {
    Write-Host "Installing GitHub CLI via winget..." -ForegroundColor Yellow
    winget install --id GitHub.cli -e --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "GitHub CLI install via winget returned exit code $LASTEXITCODE."
    }
    Refresh-SessionPath
}
```

Ensure:
- The block is placed in a PowerShell section, not inside a `try/catch` that swallows unrelated errors.
- The block uses `Test-CommandExists`, `Refresh-SessionPath`, and the same `--accept-*-agreements` flags as the existing winget calls.
- Indentation matches the surrounding block (the script uses 4 spaces).

- [ ] **Step 4: Syntax-check the PowerShell file**

```bash
pwsh -NoProfile -Command "Get-Command -Syntax -Name /home/jlipworth/GNU_files/.worktrees/nvim-git-parity/setup-dev-tools.ps1" 2>&1 | tail -5
```

If `pwsh` is available. Expected: no parse errors. If `pwsh` is not installed on the Linux dev host, skip this step and note it — the syntax will be validated by the next full CI run on a Windows host.

- [ ] **Step 5: Commit**

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-git-parity
git add setup-dev-tools.ps1
git commit -m "Install GitHub CLI on Windows for octo.nvim"
```

---

## Task 4: Document the Git bindings

**Files:**
- Modify: `docs/NEOVIM_KEYBINDINGS.md`

- [ ] **Step 1: Inspect the current doc structure**

```bash
head -20 /home/jlipworth/GNU_files/.worktrees/nvim-git-parity/docs/NEOVIM_KEYBINDINGS.md
tail -15 /home/jlipworth/GNU_files/.worktrees/nvim-git-parity/docs/NEOVIM_KEYBINDINGS.md
```

Expected: a markdown doc. The Jupyter and Claude Code sub-specs appended their sections at the end; do the same for "Git" for consistency.

- [ ] **Step 2: Append the Git section at the end of the file**

Append this markdown content exactly (starts with a blank line, ends with the Spacemacs-translation table):

```markdown

## Git

`<leader>gg` opens Neogit — a Magit-style status buffer. Stage with `s`,
unstage with `u`, commit with `cc`, push with `Pp`, pull with `Pl`,
fetch with `Pf`, rebase with `r`. The full Neogit cheatsheet lives
upstream at github.com/NeogitOrg/neogit.

`<leader>gi` / `<leader>gp` open GitHub issues / PRs via Octo. Octo
requires the `gh` CLI to be authenticated — run `gh auth login` once
per machine. On Windows this is installed by `setup-dev-tools.ps1` via
winget; on Linux / macOS it comes from `Brewfile.git`.

`<leader>gh*` hunk bindings are LazyVim's gitsigns defaults and are not
customized here.

### Status / stage / commit (group `<leader>g` — "git")

| Keys | Action |
|---|---|
| `<leader>gg` | Open Neogit status |
| `<leader>gG` | Lazygit (cwd) — LazyVim default, unchanged |
| `<leader>gc` | Neogit commit popup |
| `<leader>gl` | Neogit log popup |
| `<leader>gr` | Neogit pull popup |
| `<leader>gP` | Neogit push popup |

### Diff / file history

| Keys | Action |
|---|---|
| `<leader>gd` | Diffview (working tree vs HEAD) |
| `<leader>gD` | Diffview (origin/HEAD..HEAD) |
| `<leader>gf` | Git Current File History (Snacks picker) |
| `<leader>gF` | Diffview file history (current buffer) |
| `<leader>gx` | Close Diffview |

### Blame / browse

| Keys | Action |
|---|---|
| `<leader>gb` | Git Blame Line (Snacks) |
| `<leader>gB` | Git Browse (open in browser) |
| `<leader>gY` | Copy Git Browse URL |

### Hunks — gitsigns

| Keys | Action |
|---|---|
| `<leader>ghs` | Stage hunk |
| `<leader>ghr` | Reset hunk |
| `<leader>ghS` | Stage buffer |
| `<leader>ghu` | Undo stage hunk |
| `<leader>ghR` | Reset buffer |
| `<leader>ghp` | Preview hunk inline |
| `<leader>ghb` | Blame line (full) |
| `<leader>ghB` | Blame buffer |
| `<leader>ghd` | Diff this |
| `<leader>ghD` | Diff this against `~` |

### GitHub issues / PRs — Octo

| Keys | Action |
|---|---|
| `<leader>gi` | List Issues (Octo) |
| `<leader>gI` | Search Issues (Octo) |
| `<leader>gp` | List PRs (Octo) |
| `<leader>gR` | List Repos (Octo) |
| `<leader>gS` | Octo search |

Inside `octo://` buffers, `<localleader>` groups cover assignee / comment
/ label / issue / react / pr / review. See the octo.nvim docs upstream.

### Spacemacs translation

| Spacemacs | Neovim here |
|---|---|
| `SPC g s` (Magit status) | `<leader>gg` |
| `SPC g c c` (Magit commit) | `<leader>gc` |
| `SPC g l l` (Magit log) | `<leader>gl` |
| `SPC g f f` (Magit pull) | `<leader>gr` |
| `SPC g P p` (Magit push) | `<leader>gP` |
| `SPC g f h` (file hunk stage) | `<leader>ghs` |
| `SPC g h i` (Forge list issues) | `<leader>gi` |
| `SPC g h p` (Forge list PRs) | `<leader>gp` |
```

Do NOT include the triple-backtick fences above in the file — they are delimiting the markdown content for the implementer. Append the content BETWEEN the fences (starting with the blank line, ending with the final table row).

- [ ] **Step 3: Verify the append looks right**

```bash
tail -80 /home/jlipworth/GNU_files/.worktrees/nvim-git-parity/docs/NEOVIM_KEYBINDINGS.md
```

Expected: the new "Git" section appears at the bottom with all six tables, the three explanatory paragraphs, and the Spacemacs-translation table.

- [ ] **Step 4: Commit**

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-git-parity
git add docs/NEOVIM_KEYBINDINGS.md
git commit -m "Document Neogit/Diffview/Octo bindings in NEOVIM_KEYBINDINGS.md"
```

---

## Task 5: Full validation pass

No code changes in this task — run the full headless validation suite and record results. Any failure is a blocker; go back and fix.

- [ ] **Step 1: Full config parse**

```bash
cd /home/jlipworth/GNU_files/.worktrees/nvim-git-parity
NVIM_APPNAME=nvim_parity_git nvim --headless -c 'qall' 2>&1 | tail -5
```

Expected: empty output.

- [ ] **Step 2: Plugin count is 51–53**

```bash
NVIM_APPNAME=nvim_parity_git nvim --headless \
  -c 'lua print(require("lazy").stats().count)' \
  -c 'qall' 2>&1 | tail -3
```

Expected: a number between 51 and 53 (pre-sub-spec-3 baseline was 48; we add neogit, diffview, octo, possibly plenary/telescope transitively). If the count is < 51 or > 55, something is off — investigate and report.

- [ ] **Step 3: All three modules load**

```bash
for mod in neogit diffview octo; do
  NVIM_APPNAME=nvim_parity_git nvim --headless \
    -c "lua require(\"$mod\"); print(\"$mod OK\")" \
    -c 'qall' 2>&1 | tail -1
done
```

Expected: three `<name> OK` lines. Anything else is a blocker.

- [ ] **Step 4: Jupyter regression guard**

```bash
bash tests/nvim/run_nvim_tests.sh 2>&1 | tail -5
```

Expected: `ALL TESTS PASSED` for both cells and repl specs. A failure means sub-spec 3 broke sub-spec 1 — report BLOCKED.

- [ ] **Step 5: Claude Code regression guard**

```bash
NVIM_APPNAME=nvim_parity_git nvim --headless \
  -c 'lua require("claudecode"); print("OK")' \
  -c 'qall' 2>&1 | tail -3
```

Expected: `OK`. Sub-spec 2 should be undisturbed.

- [ ] **Step 6: gitsigns still loads (regression guard)**

```bash
NVIM_APPNAME=nvim_parity_git nvim --headless \
  -c 'lua require("gitsigns"); print("OK")' \
  -c 'qall' 2>&1 | tail -3
```

Expected: `OK`. Note that `<leader>gh*` hunk bindings are installed by
gitsigns' `on_attach` callback and only appear once a git-tracked buffer
is loaded, so a `maparg` check in a bare headless session would be a
false negative — checking the module load is the meaningful regression
guard here.

- [ ] **Step 7: `checkhealth` smoke**

```bash
NVIM_APPNAME=nvim_parity_git nvim --headless \
  -c 'checkhealth neogit' \
  -c 'qall' 2>&1 | grep -iE "^\s*(error|fail)" | head
```

Expected: no output. A missing `git` on PATH would surface here as an error; host-environment issue if so.

- [ ] **Step 8: Manual smoke test (HUMAN-RUN, not automated)**

Document this in the report; do NOT attempt to run it headlessly — `gh auth login`, Neogit staging, and Diffview all need a real terminal.

1. Start nvim against this config: `NVIM_APPNAME=nvim_parity_git nvim` inside a GitHub-tracked repo.
2. Hit `<leader>gg`. Neogit status buffer opens. Confirm staged/unstaged sections render.
3. Modify a file. Press `s` on it in Neogit to stage, `u` to unstage. Confirm the sections update.
4. Press `cc` to commit. A commit message buffer opens. Type a message, `:wq`. Confirm the commit appears in `git log`.
5. Hit `<leader>gd`. Diffview opens with file-tree left, diff right. Press `<leader>gx` to close.
6. Hit `<leader>gF` on a modified file. Diffview file history opens with the file's revision list.
7. Run `gh auth login` if not already authenticated. Hit `<leader>gi`. Octo lists open issues. Hit `<leader>gp`. Octo lists open PRs.
8. Confirm `<leader>ghs` (stage hunk via gitsigns) still works in a buffer with unstaged hunks.

- [ ] **Step 9: If any headless step failed, commit fix(es) now**

```bash
# Only if fixes were made:
git add -A
git diff --cached --stat
git commit -m "Fixups from git-parity validation"
```

(Skip entirely if no fixes were needed.)

---

## Self-Review

### Spec coverage

Mapping each spec requirement to a task:

- §1 Goal (Neogit + Diffview + Octo via `<leader>g*`, gitsigns untouched, both OS's) → Tasks 1–4 collectively.
- §1 Success Criteria 1 (`<leader>gg` opens Neogit) → Task 2 Step 7 (keymap resolves to Neogit), Task 5 Step 8 (manual).
- §1 Success Criteria 2 (`<leader>gd` / `<leader>gD` Diffview) → Task 2 Step 2 defines bindings, Task 5 Step 8 manual smoke.
- §1 Success Criteria 3 (octo issues/PRs) → Task 1 Step 2 adds the extra; Task 2 Step 2 fixes collisions; Task 5 Step 8 manual smoke.
- §1 Success Criteria 4 (works on Windows) → Task 3 adds `gh` via winget; verified out-of-band by the user on the Windows target.
- §1 Success Criteria 5 (no Jupyter/Claude/gitsigns regression) → Task 5 Steps 4, 5, 6.
- §2 Plugin stack (+3: neogit, diffview, octo) → Task 2 Step 2 for neogit and diffview; Task 1 Step 2 for octo via extra.
- §3 Keymap layout → Task 2 Step 2 defines all bindings and collision fixups; Task 4 documents them.
- §4 Install wiring (only Windows `gh` new; Unix already has it) → Task 3.
- §5 Implementation structure (4 files touched) → Tasks 1 (lazy.lua), 2 (git.lua), 3 (ps1), 4 (docs).
- §6 Testing (8 headless checks + manual) → Task 5 Steps 1–8.
- §7 Documentation → Task 4.
- §8 Risks (diffview quiescence, gr/gP collision, gg shadow) → handled in spec text; no code action required beyond the collision fixup already in Task 2.
- §9 Out of scope (debug/polish, gh.nvim, GitLab-specific) → explicitly not addressed here.

No spec requirement is unclaimed.

### Placeholder scan

- No TBD / TODO / FIXME / "similar to" / "appropriate error handling" / vague test descriptions.
- Every code block is complete and directly paste-able, except Task 3 Step 3's PowerShell `Example:` which is explicitly labeled "adjust to actual surrounding code" because the exact anchor line cannot be known without reading the script at implementation time. This is intentional and matches the existing setup-dev-tools.ps1 insert-point idiom used in prior sub-specs.
- Every shell command has an explicit Expected output.

### Type consistency

- Extra import string `"lazyvim.plugins.extras.util.octo"` appears identically in spec §5, Task 1 Step 2, and matches the upstream file at `~/.local/share/nvim_parity_git/lazy/LazyVim/lua/lazyvim/plugins/extras/util/octo.lua`.
- Plugin GitHub slugs (`NeogitOrg/neogit`, `sindrets/diffview.nvim`, `pwntester/octo.nvim`) are identical across spec §2, Task 2 Step 2, and the validation loop in Task 5 Step 3.
- Keymap names (`<leader>gg`, `<leader>gc`, `<leader>gl`, `<leader>gr`, `<leader>gP`, `<leader>gd`, `<leader>gD`, `<leader>gF`, `<leader>gx`, `<leader>gi`, `<leader>gp`, `<leader>gI`, `<leader>gR`, `<leader>gS`, `<leader>gh*`) are consistent between spec §3, the spec file's keys blocks, the docs append in Task 4, and the validation steps.
- Plugin count expectation (51–53) in Task 5 Step 2 is consistent with "48 baseline + 3 plugins + optional plenary/telescope transitive deps" reasoning in spec §2.
- `gh` CLI is referenced identically in spec §4, Task 3, and Task 4 docs append.

No drift detected.
