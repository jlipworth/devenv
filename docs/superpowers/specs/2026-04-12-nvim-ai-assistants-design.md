# Neovim AI Assistants — Design

Date: 2026-04-12
Status: Draft (awaiting user review)
Branch: `feature/nvim-parity`
Scope: Sub-project 2 of 4 in the Neovim Spacemacs-parity pass.

## 1. Goal & Non-Goals

### Goal

Wire Claude Code into the Neovim config so it can be toggled, focused, and
fed selections/buffers from inside nvim, on both Linux and native Windows
via the existing no-admin install scripts. Use LazyVim's pre-baked
`claudecode` extra with its default keymaps so there is almost no bespoke
code to maintain.

### Non-Goals

- **Codex integration.** The user runs Codex in a separate terminal outside
  nvim and has no interest in in-editor wiring for it.
- **Custom overrides to claudecode defaults.** "Full-force" means accept
  LazyVim's default keymap layout and `opts = {}`. Any future tuning is a
  follow-up, not this spec.
- **Prompt libraries or snippet integration.** Orthogonal; out of scope.
- **GitHub Copilot, Avante, Codeium, Supermaven, Tabnine, Sidekick.** Not
  installed, not investigated. User picked Claude Code explicitly.
- **No-abandonware audit tooling.** This spec is intentionally tiny.

### Success Criteria

1. After `lazy sync`, `<leader>ac` opens a vertical split running Claude
   Code with the current repo's context.
2. `<leader>as` on a visual selection sends that selection to the Claude
   session as context.
3. `<leader>aa` / `<leader>ad` accept/deny a Claude-proposed diff inline.
4. Works identically on the Windows install produced by
   `setup-dev-tools.ps1` (no extra admin prompts, no extra PATH tweaks).
5. No regression: existing `,j*` Jupyter bindings, navigation motions, and
   LazyVim defaults continue to work.

## 2. Plugin Stack

| Component | Plugin | Maintenance status (2026-04-12) |
|---|---|---|
| Claude Code ↔ nvim WebSocket bridge, toggle, diff review | `coder/claudecode.nvim` via `lazyvim.plugins.extras.ai.claudecode` | Last commit 2026-03-04 (~5 weeks), 2,512⭐ |

Net plugin delta: **+1** (claudecode.nvim). `MunifTanjim/nui.nvim` comes
along transitively; it is already used elsewhere in the LazyVim base.

Because we are importing a LazyVim extra rather than writing a custom
plugin spec, the `nvim-parity` repo owns only the one-line import — all
keymap defaults, opts, and dependency declarations come from LazyVim
upstream. Maintenance burden: effectively zero.

### Rejected Alternatives

- **DIY plugin spec for `coder/claudecode.nvim`.** Would duplicate what
  LazyVim already maintains and drift over time. LazyVim's extra is the
  canonical integration, tracked by the LazyVim team. No reason to fork.
- **`snacks.terminal.toggle` with `cmd = "claude"` only.** Strictly weaker:
  loses the diff-review bindings, the send-selection binding, and the
  WebSocket discovery between nvim and the CLI. Only worth considering
  if `claudecode.nvim` were unmaintained, which it isn't.
- **Codex integration.** User declined; see §1 Non-Goals.

## 3. Keymap Layout

All bindings come from LazyVim's `claudecode` extra. The repo does not
override any of them.

### Execution / Session — `<leader>a` subtree (group label "+ai")

| Keys | Action |
|---|---|
| `<leader>ac` | Toggle Claude Code split |
| `<leader>af` | Focus Claude Code split |
| `<leader>ar` | Resume last Claude session |
| `<leader>aC` | Continue current Claude session |
| `<leader>ab` | Add current buffer to Claude context |
| `<leader>as` | Send visual selection to Claude (visual mode); in file-tree filetypes (NvimTree / neo-tree / oil), add the file under cursor |

### Diff Review — `<leader>a` subtree

| Keys | Action |
|---|---|
| `<leader>aa` | Accept Claude-proposed diff |
| `<leader>ad` | Deny Claude-proposed diff |

### Which-Key Integration

The LazyVim extra already registers `<leader>a` as the `+ai` group, so
which-key discovery works with no further wiring in this repo.

## 4. Install & Windows Wiring

### `setup-dev-tools.ps1`

**No changes needed.** Lines 997–1043 already install Claude Code via
`npm install -g @anthropic-ai/claude-code` and wire
`CLAUDE_CODE_GIT_BASH_PATH` for Windows. Version check runs afterward.

### `prereq_packages.sh`

**No changes needed.** Line ~1600 already runs the native installer
(`curl -fsSL https://claude.ai/install.sh | bash`) and symlinks CLI
config (`~/.claude/CLAUDE.md`, `settings.json`, statusline script).

### Windows Compatibility Notes

- `claudecode.nvim` uses a localhost WebSocket for nvim↔CLI IPC. Windows
  Defender firewall does not prompt for localhost loopback binds, so no
  admin action is needed.
- The CC CLI respects `CLAUDE_CODE_GIT_BASH_PATH` on Windows. Already set
  by the install script.
- Nui.nvim is pure Lua — no platform-specific build artifacts.

### No Changes Needed

- `Brewfile.*` — CC CLI is npm/native-installer, not brew.
- `makefile` — no new targets.
- `ci/` Docker image — CI does not exercise the Claude Code integration
  (no API key available, no interactive session).

## 5. Implementation Structure

Single one-line change to `nvim/lua/config/lazy.lua`, appending to the
`spec` table:

```lua
{ import = "lazyvim.plugins.extras.ai.claudecode" },
```

No new files. No Lua in `nvim/lua/plugins/` — the extra lives upstream.

### File Size Expectation

+1 line in `lazy.lua`, ~30 lines appended to `docs/NEOVIM_KEYBINDINGS.md`.
That is the entire code surface.

## 6. Testing Strategy

### Headless Checks

After the import line lands:

```bash
# Config parses
NVIM_APPNAME=nvim_parity_test nvim --headless -c 'qall'

# Plugin count increased by ~1 (claudecode.nvim) + transitive deps
NVIM_APPNAME=nvim_parity_test nvim --headless \
  -c 'lua print(require("lazy").stats().count)' -c 'qall'

# claudecode module loads without error
NVIM_APPNAME=nvim_parity_test nvim --headless \
  -c 'lua require("claudecode")' -c 'qall' 2>&1 | grep -iE "error|fail"
```

### Manual Smoke Test

Run once on Linux, once on a Windows target:

1. In any nvim buffer inside a git repo, hit `<leader>ac`. A vertical
   split opens with `claude` running.
2. In a file with code, visual-select a few lines and hit `<leader>as`.
   The selection appears as context in the Claude session.
3. Ask Claude to propose an edit. When it produces a diff, hit
   `<leader>aa` to accept or `<leader>ad` to deny. Confirm the buffer
   updates / does not update accordingly.
4. `<leader>af` refocuses the Claude split if the cursor is in a code
   buffer.

### CI

Not added. No API key available in Woodpecker, and the integration is
interactive by nature.

### Out of Scope

- Automated tests for the WebSocket protocol (claudecode.nvim's own test
  suite covers that).
- Automated tests for diff accept/deny (requires a mock CC session).

## 7. Documentation

Append a "Claude Code" section to `docs/NEOVIM_KEYBINDINGS.md` that
reproduces the keymap tables from §3 and includes a short paragraph:

> `<leader>ac` toggles a vertical split running the `claude` CLI. The
> split and the CLI discover each other over a localhost WebSocket — no
> further configuration needed. Use `<leader>as` in visual mode to send
> the current selection as context, and `<leader>aa` / `<leader>ad` to
> accept or deny proposed diffs inline.

Preserve the existing Spacemacs-translation framing in the file.

## 8. Risks & Open Questions

### Risks

1. **LazyVim drift.** If the LazyVim team renames or restructures
   `plugins.extras.ai.claudecode`, the import line breaks. Mitigation:
   LazyVim pins extras via `lazy-lock.json`, and the extras namespace has
   been stable for over a year.
2. **claudecode.nvim upstream breakage.** New releases occasionally
   change keymap names. Mitigation: `lazy-lock.json` pins the current
   working version; updates go through `:Lazy sync` with review.
3. **Windows WebSocket binding.** Defender normally ignores loopback
   binds, but corporate policy / third-party EDR could interfere. If
   observed, fall back to stdio IPC (claudecode.nvim supports it as an
   opt). Not wired unless observed.

### Resolved Decisions

- LazyVim extra vs custom spec → LazyVim extra.
- Codex in-editor integration → no.
- Keymap prefix → `<leader>a` (LazyVim default).
- Full-force config → accept `opts = {}` defaults.
- No-abandonware audit tooling → dropped; handle via skill/reference.

## 9. Out of Scope (for this sub-spec)

Deferred to sibling sub-specs:

- **Sub-spec 3**: Git parity (neogit / diffview / gitsigns refinements).
- **Sub-spec 4**: Debug + polish (nvim-dap, visual-multi, spell, snippet
  verification).

Each lands its own design doc under `docs/superpowers/specs/`.
