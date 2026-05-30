# Neovim Git Parity — Design

Date: 2026-04-12
Status: Draft (awaiting user review)
Branch: `feature/nvim-parity`
Scope: Sub-project 3 of 4 in the Neovim Spacemacs-parity pass.

## 1. Goal & Non-Goals

### Goal

Bring Neovim to rough parity with Spacemacs' git workflow (Magit + Forge)
by wiring in:

- **Neogit** — staging / commit / branch / rebase UI (Magit analogue).
- **Diffview.nvim** — side-by-side and merge-conflict diff viewer,
  required by Neogit for its inline diff buffers.
- **Octo.nvim** — GitHub issues / PRs inside nvim (Forge analogue).

The `<leader>g*` subtree is the LazyVim default for "+git"; we use it
unchanged. **gitsigns** remains on LazyVim defaults with no local
customization. All three additions must work unchanged on Linux and on
native Windows via the existing install scripts.

### Non-Goals

- **gitsigns customization.** LazyVim's `<leader>gh*` hunk bindings,
  signs, and numhl defaults are sufficient. No local spec for
  `lewis6991/gitsigns.nvim`.
- **lazygit replacement.** LazyVim wires `<leader>gg` to `Snacks.lazygit`
  when the `lazygit` binary is present. Neogit overrides that specific
  binding because it is the natural Magit-parity keystroke; users who
  still want lazygit can invoke it via `:lua Snacks.lazygit()` or the
  `<leader>gG` cwd-scoped binding we leave intact. No attempt is made to
  remove lazygit from the install scripts.
- **gh.nvim (ldelossa).** The `lazyvim.plugins.extras.util.gh` extra wires
  a different PR review workflow under `<leader>G*`. Out of scope here;
  user picked octo.nvim explicitly.
- **Forge-style notifications / email threading.** Octo covers
  issues/PRs/comments; it does not replicate Spacemacs Forge's email
  integration and we do not add it.
- **GitLab/Gitea-specific tooling.** Octo speaks GitHub and GitLab via
  the `gh` / `glab` CLI; Gitea is out of scope.
- **Auto-login / token prompting.** The `gh auth login` step is a manual
  one-time user action; the install scripts install the CLI but do not
  touch credentials.

### Success Criteria

1. After `lazy sync`, `<leader>gg` opens the Neogit status buffer.
2. `<leader>gd` opens a Diffview for the working tree against `HEAD`,
   and `<leader>gD` (or similar) for any arbitrary ref pair.
3. `<leader>gi` lists open GitHub issues and `<leader>gI` opens an Octo
   issue search prompt; `<leader>gp` lists open PRs and `<leader>gP`
   opens an Octo PR search prompt. These match the upstream LazyVim
   octo-extra bindings verbatim.
4. Works identically on the Windows install produced by
   `setup-dev-tools.ps1` (no extra admin prompts, no extra PATH tweaks
   beyond the existing `gh` CLI install on Linux and winget `gh` install
   on Windows — see §4).
5. No regression: existing `<leader>a*` Claude bindings, `<localleader>j*`
   Jupyter bindings, `<leader>gh*` gitsigns hunk bindings, and LazyVim
   defaults continue to work.

## 2. Plugin Stack

Freshness check performed 2026-04-12 via `gh api repos/<owner>/<repo>/commits`:

| Component | Plugin | Stars | Last commit | Status |
|---|---|---|---|---|
| Magit-style git UI | `NeogitOrg/neogit` | 5,281 | 2026-04-08 (4 days) | Active |
| Side-by-side + merge-conflict diff | `sindrets/diffview.nvim` | 5,492 | 2024-06-13 (~22 months) | **Quiescent (WARN, accepted)** — see Risks §8 |
| GitHub PR / issue browser | `pwntester/octo.nvim` | 3,229 | 2026-04-12 (today) | Active |

Net plugin delta: **+3** (neogit, diffview, octo) plus transitive deps
(`nui.nvim` is already pulled in by claudecode; `plenary.nvim` is already
a LazyVim base dep; `telescope.nvim` is pulled in by the octo extra via
its picker-autodetect block). Expected final plugin count: **51-53**
from the current 48 baseline.

### Rejected Alternatives

- **gitsigns-only, no Neogit.** Strictly weaker. gitsigns handles hunks,
  not staging-area workflows, commit editing, rebase, or branch ops.
- **`kdheepak/lazygit.nvim` (or leave LazyVim's Snacks.lazygit default).**
  Works, but lazygit is a TUI overlay — no buffer-native commit-edit UI,
  no text-object diff navigation, no inline stage/unstage. Neogit is the
  Magit-equivalent workflow the user asked for.
- **`ldelossa/gh.nvim` (LazyVim's `extras.util.gh`).** Uses a different
  mental model (litee panel, `<leader>G*` subtree). User picked octo.
- **`junegunn/fugitive-vim`.** Maintenance-minimal and Vim-native, but
  weaker than Neogit for interactive rebase and weaker than Octo for
  GitHub. Fails the "one clear tool per job" bar.
- **Keeping diffview off entirely.** Neogit has a soft dep on diffview
  for its "D" / "d" diff popup. Without it, `:Neogit diff` falls back to
  a plain vimdiff that lacks file-list navigation. The UX gap is large;
  the freshness risk is small (see §8).

## 3. Keymap Layout

Bindings come from (a) the LazyVim octo extra upstream, (b) a local spec
for neogit + diffview in `nvim/lua/plugins/git.lua`. No Neogit defaults
are overridden; octo's defaults are accepted as-is.

### Status / stage / commit — `<leader>g` subtree (group label "+git")

| Keys | Action | Source |
|---|---|---|
| `<leader>gg` | Open Neogit status | local spec (overrides LazyVim's default `Snacks.lazygit(Root Dir)`) |
| `<leader>gG` | Lazygit (cwd) | LazyVim default, unchanged |
| `<leader>gc` | Neogit commit popup | local spec |
| `<leader>gl` | Neogit log popup | local spec (overrides LazyVim's picker-extra `<leader>gl` → `git_commits`; we accept the override because Neogit log is richer) |
| `<leader>gr` | Neogit pull popup | local spec (overrides LazyVim octo's `<leader>gr` → "List Repos (Octo)"; we prefer Neogit's pull here — see §8 risk note) |
| `<leader>gP` | Neogit push popup | local spec (overrides LazyVim octo's `<leader>gP` → "Search PRs" — see §8) |

Note on `<leader>gr` / `<leader>gP` collisions: octo's defaults collide
with Neogit's conventional pull/push popups. The resolution below keeps
Neogit's pull/push bindings and moves octo repos/search to `<leader>gR`
and `<leader>gS` via a local keys override on the octo spec (see §5).

### Diff / file history — `<leader>g` subtree

| Keys | Action | Source |
|---|---|---|
| `<leader>gd` | `:DiffviewOpen` (working tree vs HEAD) | local spec (overrides LazyVim picker-extra `<leader>gd` → "Git Diff (files)") |
| `<leader>gD` | `:DiffviewOpen origin/HEAD...HEAD` | local spec |
| `<leader>gf` | Git Current File History (Snacks picker) | LazyVim default, unchanged |
| `<leader>gF` | `:DiffviewFileHistory %` | local spec (diffview's richer file-history UI for the current buffer) |
| `<leader>gx` | `:DiffviewClose` | local spec |

### Blame / browse — `<leader>g` subtree

| Keys | Action | Source |
|---|---|---|
| `<leader>gb` | Git Blame Line (Snacks) | LazyVim default, unchanged |
| `<leader>gB` | Git Browse (open in browser) | LazyVim default, unchanged |
| `<leader>gY` | Copy Git Browse URL to clipboard | LazyVim default, unchanged |

### Hunks — `<leader>gh*` (gitsigns, LazyVim defaults unchanged)

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

### GitHub issues / PRs — Octo — `<leader>g` subtree

From LazyVim's `extras.util.octo` (unchanged except for the gr/gP
collision fixups above):

| Keys | Action |
|---|---|
| `<leader>gi` | List Issues (Octo) |
| `<leader>gI` | Search Issues (Octo) |
| `<leader>gp` | List PRs (Octo) |
| `<leader>gR` | List Repos (Octo) — relocated from octo's `<leader>gr` |
| `<leader>gS` | Octo search — relocated from octo's `<leader>gS` (no collision; keep as-is) |

Per-buffer `<localleader>` bindings inside `octo://` buffers (assignee /
comment / label / issue / react / pr / review / goto_issue groups) are
inherited verbatim from the octo extra; see
`~/.local/share/nvim_parity_git/lazy/LazyVim/lua/lazyvim/plugins/extras/util/octo.lua`.

### Which-Key Integration

LazyVim registers `<leader>g` as the `+git` group already (see
`lazyvim/plugins/editor.lua`:74 for `<leader>gh` = "hunks"). Neogit's
spec does not need to re-register the group label; octo's spec already
adds per-binding `desc` entries.

## 4. Install & Windows Wiring

### Prereqs already installed

- **`git`** — assumed present everywhere (used throughout bootstrap).
- **`lazygit`** — installed on macOS/Linux via `Brewfile.cli_tools`; on
  Windows via `setup-dev-tools.ps1` (winget). Neogit does NOT depend on
  it; kept only so `<leader>gG` (cwd lazygit) still works.
- **`gh` (GitHub CLI)** — required by Octo for GitHub auth / API calls.
  - macOS/Linux: already installed via `brewfiles/Brewfile.git` (`brew "gh"`),
    which `prereq_packages.sh` invokes at line 383.
  - Windows: **NOT currently installed by `setup-dev-tools.ps1`.** A
    one-line winget install is the cleanest fix. See §4 change below.
- **Node, Python, curl, make** — unrelated; all already handled.

### `setup-dev-tools.ps1` change

Add a `winget install --id GitHub.cli` step alongside the existing
winget-managed tools (near the Git-for-Windows / lazygit install block).
This is a single-line addition; no admin prompt needed because winget
runs in user scope.

**Concretely:** in the "Core tools" section (around lines 380–460 where
Git and Neovim are installed), append:

```powershell
if (-not (Test-CommandExists "gh")) {
    winget install --id GitHub.cli -e --accept-source-agreements --accept-package-agreements
    Refresh-SessionPath
}
```

The implementation plan will locate the exact right block and match
surrounding idiom (the existing script uses `Test-CommandExists`,
`Refresh-SessionPath`, and `Add-UserPathOnce`; the new block should mirror).

### `prereq_packages.sh` change

**None.** `gh` is already in `brewfiles/Brewfile.git` (line 5), which is
installed unconditionally on Darwin and Linux/Linuxbrew paths at
`prereq_packages.sh:383`.

### Windows Compatibility Notes

- Neogit and Diffview are pure Lua; no native build artifacts, no
  platform-specific binaries. They just shell out to `git`, which both
  OSes provide.
- Octo shells out to `gh`. With GitHub.cli on PATH (post-change), auth
  uses the standard `gh auth login` flow on either OS.
- Neogit's commit-message buffer is a plain filetype=`NeogitCommitMessage`
  buffer; no terminal emulation, no PTY issues on Windows.

### No Changes Needed

- `Brewfile.*` — `gh` already in `Brewfile.git`.
- `makefile` — no new targets.
- `ci/` Docker image — CI does not exercise any of these (no GitHub auth
  token available in Woodpecker, no interactive staging workflow).

## 5. Implementation Structure

### Files touched

```
nvim/lua/config/lazy.lua           # +1 line: import octo extra
nvim/lua/plugins/git.lua           # NEW: neogit + diffview spec + octo overrides
docs/NEOVIM_KEYBINDINGS.md         # append "Git" section
setup-dev-tools.ps1                # +~5 lines: install gh via winget
```

### `nvim/lua/config/lazy.lua`

Append `{ import = "lazyvim.plugins.extras.util.octo" },` to the `spec`
table, placed after the claudecode extra import and before the local
`plugins` import (same rationale as claudecode: extras before local so
local can override).

### `nvim/lua/plugins/git.lua` (new)

```lua
return {
  -- Magit-style git UI
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",   -- inline diff popups inside Neogit
    },
    cmd = { "Neogit" },
    keys = {
      { "<leader>gg", function() require("neogit").open() end,                 desc = "Neogit" },
      { "<leader>gc", function() require("neogit").open({ "commit" }) end,     desc = "Neogit commit" },
      { "<leader>gl", function() require("neogit").open({ "log" }) end,        desc = "Neogit log" },
      { "<leader>gr", function() require("neogit").open({ "pull" }) end,       desc = "Neogit pull" },
      -- gP (push) is registered in the octo override spec below because we
      -- need to `false` octo's <leader>gP before binding our own.
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
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory", "DiffviewRefresh", "DiffviewToggleFiles" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>",                        desc = "Diffview (working tree)" },
      { "<leader>gD", "<cmd>DiffviewOpen origin/HEAD...HEAD<cr>",     desc = "Diffview (vs origin/HEAD)" },
      { "<leader>gF", "<cmd>DiffviewFileHistory %<cr>",               desc = "Diffview file history" },
      { "<leader>gx", "<cmd>DiffviewClose<cr>",                        desc = "Diffview close" },
    },
  },

  -- Fix up octo <leader>g* collisions: relocate octo's `gr` / `gP` so
  -- Neogit's pull/push can live at the conventional Magit-parity spots.
  {
    "pwntester/octo.nvim",
    keys = {
      { "<leader>gr", false },   -- was "List Repos (Octo)" in octo extra
      { "<leader>gP", false },   -- was "Search PRs (Octo)" in octo extra
      { "<leader>gR", "<cmd>Octo repo list<CR>",   desc = "List Repos (Octo)" },
      -- Re-register Neogit's push on <leader>gP:
      { "<leader>gP", function() require("neogit").open({ "push" }) end, desc = "Neogit push" },
    },
  },

  -- which-key: group label already comes from LazyVim base. No addition needed.
}
```

Rationale notes inline in the spec above will be preserved as comments
in the actual file.

### File Size Expectation

- `lazy.lua`: +1 line.
- `git.lua`: ~55 lines including blank lines and comments.
- `NEOVIM_KEYBINDINGS.md`: +~45 lines appended.
- `setup-dev-tools.ps1`: +~5 lines in the core-tools block.

## 6. Testing Strategy

### Headless Checks

Run against a repo with `NVIM_APPNAME=nvim_parity_git` pointing at the
worktree's `nvim/` directory. If the symlink is missing, create it first:

```bash
ln -sfn /home/jlipworth/GNU_files/.worktrees/nvim-git-parity/nvim ~/.config/nvim_parity_git
```

Then:

```bash
# 1. Config parses
NVIM_APPNAME=nvim_parity_git nvim --headless -c 'qall' 2>&1 | tail -5

# 2. Plugin count went from 48 to 51-53
NVIM_APPNAME=nvim_parity_git nvim --headless \
  -c 'lua print(require("lazy").stats().count)' -c 'qall' 2>&1 | tail -3

# 3. Neogit module loads
NVIM_APPNAME=nvim_parity_git nvim --headless \
  -c 'lua require("neogit"); print("OK")' -c 'qall' 2>&1 | tail -3

# 4. Diffview module loads
NVIM_APPNAME=nvim_parity_git nvim --headless \
  -c 'lua require("diffview"); print("OK")' -c 'qall' 2>&1 | tail -3

# 5. Octo module loads
NVIM_APPNAME=nvim_parity_git nvim --headless \
  -c 'lua require("octo"); print("OK")' -c 'qall' 2>&1 | tail -3

# 6. User commands registered
NVIM_APPNAME=nvim_parity_git nvim --headless \
  -c 'lua print(vim.fn.exists(":Neogit"), vim.fn.exists(":DiffviewOpen"), vim.fn.exists(":Octo"))' \
  -c 'qall' 2>&1 | tail -3
# Expected: three 2s.

# 7. No Jupyter regression
bash tests/nvim/run_nvim_tests.sh 2>&1 | tail -5

# 8. No Claude Code regression
NVIM_APPNAME=nvim_parity_git nvim --headless \
  -c 'lua require("claudecode"); print("OK")' -c 'qall' 2>&1 | tail -3
```

### Manual Smoke Test

Run once on Linux, once on a Windows target:

1. In any nvim buffer inside a git repo, hit `<leader>gg`. A Neogit
   status buffer opens showing staged/unstaged/untracked sections.
2. Stage a file with `s`, unstage with `u`, commit with `cc`. Confirm
   the commit message buffer opens and `:wq` completes the commit.
3. Hit `<leader>gd`. Diffview opens showing working tree vs HEAD with
   file-tree on the left, diff on the right. `<leader>gx` closes it.
4. Hit `<leader>gF`. Diffview opens the current file's history with the
   revision list on the left.
5. Hit `<leader>gi`. Octo lists open issues for the current GitHub
   repo. Requires `gh auth status` returning OK; if not, run
   `gh auth login` first. This is a one-time user action.
6. Hit `<leader>gp`. Octo lists open PRs.
7. Confirm no regression on `<leader>gh*` gitsigns hunks and
   `<leader>ghs` / `<leader>ghr` still work in any buffer with a
   modified git-tracked file.

### CI

Not added. Neogit / diffview workflows need a real git repo with HEAD
history; octo needs `gh auth`. CI environment has neither. Unit-level
behavior is covered by each plugin's own test suite upstream.

## 7. Documentation

Append a "Git" section to `docs/NEOVIM_KEYBINDINGS.md` that reproduces
the keymap tables from §3 and includes two short explanatory paragraphs:

> `<leader>gg` opens Neogit — a Magit-style status buffer. Stage with
> `s`, unstage with `u`, commit with `cc`, push with `Pp`, pull with
> `Pl`, fetch with `Pf`, rebase with `r`. The full Neogit cheatsheet
> lives upstream at github.com/NeogitOrg/neogit.

> `<leader>gi` / `<leader>gp` open GitHub issues / PRs via Octo. Octo
> requires the `gh` CLI to be authenticated — run `gh auth login` once
> per machine. On Windows this is installed by `setup-dev-tools.ps1`
> via winget; on Linux / macOS it comes from `Brewfile.git`.

Preserve the existing Spacemacs-translation framing — add a short table
mapping `SPC g *` to the Neovim equivalents.

## 8. Risks & Open Questions

### Risks

1. **diffview.nvim quiescence — ACCEPTED by user on 2026-04-12.** Last
   commit 2024-06-13 (~22 months old as of 2026-04-12), `pushed_at`
   2024-08-02. Not archived; 5.5K stars; 132 open issues (typical for a
   mature tool). Neogit's README still lists it as the recommended diff
   integration (canonical Neogit integration), and there is no viable
   replacement / fork with meaningful daylight ahead of it. The plugin
   is feature-complete for its scope. Shipping as an accepted WARN.
   **Mitigation:** if the repo archives, Neogit falls back to plain
   vimdiff and we lose `<leader>gd / gD / gF / gx` until we pick a
   replacement (likely `akinomyoga/git-delta` + builtin `:vert diff` or
   the upcoming native-Neovim diff-view work). This is a low-probability,
   medium-impact risk; accepted.

2. **Keymap collisions with octo extra.** `<leader>gr` (octo repos) and
   `<leader>gP` (octo search PRs) collide with the conventional
   Magit-parity pull/push bindings. Resolution: relocate octo's `gr` to
   `gR`, drop octo's `gP` (covered by Octo's `<leader>gp`/`<leader>gI`
   combo for "all PRs" searching). Implemented via the local octo
   override spec in §5. **Mitigation:** documented in `NEOVIM_KEYBINDINGS.md`.

3. **Keymap collision with LazyVim lazygit default.** LazyVim binds
   `<leader>gg` → `Snacks.lazygit(Root Dir)` conditionally on the
   `lazygit` executable being present. Our Neogit spec also binds
   `<leader>gg`. Because plugin-defined keymaps in lazy.nvim specs take
   precedence over the global `vim.keymap.set` calls in LazyVim's
   `config/keymaps.lua` (specs are applied after config/keymaps at
   VeryLazy), Neogit wins. Verified by the Task 1 / Task 2 validation
   step that prints the `:map <leader>gg` target. **Mitigation:**
   `<leader>gG` (cwd lazygit) remains unshadowed for users who prefer
   lazygit.

4. **Windows `gh` install via winget.** winget has been ubiquitous on
   Windows 10 20H2+ and Windows 11 for years. The install block matches
   the pattern of the existing Git-for-Windows and lazygit installs in
   the same script, so failure modes (winget missing, source agreements)
   are already handled by surrounding retries and the script's preflight
   `winget --version` check around line 869.

5. **Octo `gh` auth.** Octo assumes the user has run `gh auth login`.
   First use prompts for login through `gh`'s standard flow; not a
   scripting failure, but worth documenting so users don't file a bug
   about "empty issue list."

### Resolved Decisions

- Local spec vs LazyVim extra for neogit/diffview → local spec; no
  LazyVim extra exists. `util/octo.lua` is used upstream.
- gitsigns customization → none; accept LazyVim defaults.
- Make-target or install-script changes → only the Windows `gh` install;
  no makefile changes.
- Freshness-audit tooling → dropped; handle via skill/reference.
- `<leader>gg` collision with Snacks.lazygit → Neogit wins, `<leader>gG`
  preserved for lazygit(cwd).

## 9. Out of Scope (for this sub-spec)

Deferred to sibling sub-specs:

- **Sub-spec 4**: Debug + polish (nvim-dap, visual-multi, spell, snippet
  verification).

Explicitly NOT in this sub-spec:

- gh.nvim integration.
- GitLab-specific workflows beyond what octo provides.
- `git-conflict.nvim` — Diffview's merge-conflict view covers this.
- Per-buffer git blame inlay / virtual text beyond LazyVim's gitsigns default.
- Signing / GPG UX polish.
