# Neovim (LazyVim) Keybinding Reference

Quick reference for Spacemacs users transitioning to Neovim with LazyVim.
This reference is grounded in the current `.spacemacs` conventions: leader key, `jk` escape, layouts/projects, which-key, and relative line numbers.
Leader key is Space (same as Spacemacs).
Major-mode leader is `,` (via `<localleader>`), matching the current `.spacemacs` setup.

This config currently uses:
- **Snacks picker** for file/search pickers
- **Snacks explorer** for the file tree
- **persistence.nvim** for session restore
- **Harpoon 2** for optional working-set / hot-file jumps
- **Neogit + Diffview + Octo** for git (`<leader>gg` is Neogit, not lazygit)
- **blink.cmp** for completion and snippet expansion (no LuaSnip)


## Getting Started

### First launch

Open Neovim in a repo:

```bash
nvim
```

Useful first commands:
- `:Lazy` — plugins
- `:Mason` — LSP/tools
- `:checkhealth` — sanity check

### Core mental model

Think of this setup as:
- **Snacks picker** = find/search things
- **buffers** = open files
- **sessions** = restore a project state
- **Harpoon 2** = optional shortlist of hot files
- **which-key** = discover commands by pressing `Space`

### 10 keys to learn first

- `Space` — leader
- `<leader>ff` — find file
- `<leader>sg` — grep project
- `<leader>fb` — buffers
- `<leader>e` — explorer
- `<leader>fp` — projects
- `<leader>qs` — restore session
- `<leader>gg` — Neogit (Magit-style status; lazygit is `<leader>gG`)
- `gd` — go to definition
- `<leader>ca` — code action
- `jk` — escape insert mode

### Sessions vs Harpoon

Use **sessions** when you want your windows, buffers, and project state back.
Use **Harpoon** when you keep bouncing between a small set of important files.


## Core Navigation

| Action | Spacemacs | LazyVim | Notes |
|--------|-----------|---------|-------|
| Escape | `jk` | `jk` | Custom (`config/keymaps.lua`) |
| Find file | `SPC f f` | `<leader>ff` | Snacks picker |
| Recent files | `SPC f r` | `<leader>fr` | Snacks picker |
| Grep project | `SPC /` | `<leader>sg` | Snacks live grep |
| File explorer | `SPC f t` | `<leader>e` | Snacks explorer |
| Buffer list | `SPC b b` | `<leader>fb` | Snacks buffers |
| Project switcher | `SPC p l` / `SPC p p` | `<leader>fp` | Project picker |
| Switch buffer | `SPC b n/p` | `[b` / `]b` | Previous/next buffer |
| Close buffer | `SPC b d` | `<leader>bd` | |
| Save file | `SPC f s` | `<C-s>` or `:w` | `<leader>w` is the **windows** group, not save |
| Command history | `SPC SPC` | `<leader>:` | Commands live at `<leader>sC` |

## Windows and Splits

| Action | Spacemacs | LazyVim | Notes |
|--------|-----------|---------|-------|
| Split vertical | `SPC w v` | `<leader>wv` or `<C-w>v` | |
| Split horizontal | `SPC w s` | `<leader>ws` or `<C-w>s` | |
| Close window | `SPC w d` | `<leader>wd` or `<C-w>c` | |
| Switch window | `SPC w w` | `<C-w>w` | |
| Move to window | `SPC w h/j/k/l` | `<C-h/j/k/l>` | LazyVim default |
| Numbered window | `Cmd-1` ... `Cmd-9` | `Cmd-1` ... `Cmd-9` | Bound in normal, visual, **insert** and **terminal** modes (insert/visual leave via `<Esc>`, terminal via `<C-\><C-n>`), matching Spacemacs' global `winum` behaviour. Ghostty uses a tmux-safe Meta encoding, so both `<D-N>` and `<M-N>` are bound |
| Resize window | `SPC w .` (transient state) | `<C-Up>` / `<C-Down>` / `<C-Left>` / `<C-Right>` | LazyVim defaults; kept, which is why multi-cursor's add-cursor keys moved to `<M-Up>`/`<M-Down>` |
| Terminal (root dir) | `SPC '` (vterm) | `<leader>ft` or `<c-/>` | Snacks terminal; `<c-/>` also closes it from terminal mode |
| Terminal (cwd) | | `<leader>fT` | Snacks terminal in the current working directory |

## Sessions / Workspace Story

Neovim does not ship with Spacemacs-style layouts, but this setup has a workable equivalent:
- **project picker** for jumping between repos
- **persistence.nvim sessions** for restoring buffers/windows per project
- **Harpoon 2** for an optional per-project working set / hot-file list
- **tmux** as an extra option on Unix/WSL/remote setups, not a requirement

| Action | LazyVim | Notes |
|--------|---------|-------|
| Projects | `<leader>fp` | Pick a repo/project |
| Restore session | `<leader>qs` | Restore current project session |
| Restore last session | `<leader>ql` | Resume last session |
| Select session | `<leader>qS` | Choose from saved sessions |
| Stop saving session | `<leader>qd` | Disable session persistence for current session |

### Layouts analog (`<leader><tab>` — tabs)

Spacemacs `SPC l 1` ... `SPC l 9` (numbered layouts) has no direct
equivalent: `<leader>l` is `:Lazy` in LazyVim, so the numbered-layout keys
are deliberately not rebound. The closest thing is LazyVim's tab group,
where each tab page carries its own window layout.

| Action | LazyVim | Notes |
|--------|---------|-------|
| New tab | `<leader><tab><tab>` | New tab page (new window layout) |
| Next / previous tab | `<leader><tab>]` / `<leader><tab>[` | |
| First / last tab | `<leader><tab>f` / `<leader><tab>l` | |
| Close tab | `<leader><tab>d` | |
| Close other tabs | `<leader><tab>o` | |

Numbered jumps are `1gt`, `2gt`, ... (built-in Vim), or `:tabnext N`.

## Harpoon 2 (Optional Working Set)

Harpoon 2 is installed as an optional helper for the files you revisit constantly inside one repo. It is **not** the workspace/session system.

| Action | LazyVim | Notes |
|--------|---------|-------|
| Add current file | `<leader>ha` | Add file to Harpoon list |
| Open Harpoon menu | `<leader>hh` | Show/edit the current working set |
| Jump to file 1-4 | `<leader>h1` ... `<leader>h4` | Fast jump to saved files |
| Previous Harpoon file | `<leader>hp` | Cycle backward through list |
| Next Harpoon file | `<leader>hn` | Cycle forward through list |

## Windows / PowerShell Notes

- `.ps1` files are supported via `powershell_es` when `pwsh` or `powershell` is available on PATH.
- This repo config asks Mason to install `powershell-editor-services` only when a PowerShell executable is present.
- PowerShell support here is for **windows-scripts style editing/LSP**, not full Spacemacs layer parity.
- On Windows, Mason itself also expects a PowerShell executable to be available.

## Git

See the **Git (Neogit / Diffview / Octo)** section near the end of this
file for the full current set of Git bindings. The old three-row summary
that used to live here is now superseded by that section.

## LSP

| Action | Spacemacs | LazyVim | Notes |
|--------|-----------|---------|-------|
| Go to definition | `g d` | `gd` | Available when an LSP attaches |
| Go to references | `g r` | `gr` | Available when an LSP attaches |
| Hover docs | `K` | `K` | Available when an LSP attaches |
| Rename symbol | `SPC l r` | `<leader>cr` | Available when an LSP attaches |
| Code action | `SPC l a` | `<leader>ca` | Available when an LSP attaches |
| Format buffer | `SPC l =` | `<leader>cf` | |
| Diagnostics list | `SPC l e` | `<leader>xx` | Trouble |
| Next diagnostic | `] d` | `]d` | |
| Prev diagnostic | `[ d` | `[d` | |
| LSP info | | `:LspInfo` | Check attached servers |

### Language support

All LazyVim extras are imported from `nvim/lua/config/lazy.lua` (they must be
imported before the `plugins` directory, or LazyVim warns "import order is
incorrect" on interactive start). Extras enabled for Spacemacs layer parity:

| Area | Extras |
|---|---|
| Core languages | `lang.python`, `lang.typescript`, `lang.json`, `lang.yaml`, `lang.toml`, `lang.markdown`, `lang.sql`, `lang.tex`, `lang.tailwind`, `lang.clangd`, `lang.cmake` |
| Added for layer parity | `lang.rust`, `lang.ocaml`, `lang.terraform`, `lang.docker`, `lang.ansible`, `lang.helm` |
| Linting | `linting.eslint` — with `vim.g.lazyvim_eslint_auto_format = false`, so prettier stays the sole JS/TS formatter |
| Conditional | `lang.r` loads only when `Rscript` is on PATH |
| Other | `ai.claudecode`, `util.octo`, `dap.core` |

Extra LSP servers wired up in `nvim/lua/plugins/lang.lua` on top of what the
extras bring: `bashls`, `html`, `cssls`, `emmet_ls`, `vimls`,
`nginx_language_server`, `sqls`, `powershell_es` (only when `pwsh`/`powershell`
is on PATH) and `sourcekit` (Swift — only when `sourcekit-lsp` is on PATH; it
ships with the toolchain and is never installed by Mason). `clangd` is started
with `--experimental-modules-support` appended to LazyVim's own flags, for
C++20 modules.

VimTeX's PDF viewer (`,lv` forward search) is Skim on macOS and zathura
elsewhere. Skim is installed by `brewfiles/Brewfile.latex` on macOS; zathura is
not installed by this repo — add it from your distro if you want Linux
forward/inverse search. VimTeX requires Neovim >= 0.12.4 and refuses to load
below it — see `NEOVIM_MIN_VERSION` in `versions.conf`.

`NVIM_DISABLE_AUTO_INSTALLS=1` (used by CI) opts every server out of Mason and
empties the treesitter/mason `ensure_installed` lists.

`nvim/lazy-lock.json` is tracked in git. `:Lazy install` / `:Lazy update`
rewrite it — commit that change deliberately, and use `:Lazy restore` to get
back to the pinned set.

## Search and Replace

| Action | Spacemacs | LazyVim | Notes |
|--------|-----------|---------|-------|
| Search in buffer | `/` | `/` | Same |
| Search word under cursor | `*` | `*` | Same |
| Search and replace | `:%s/old/new/g` | `:%s/old/new/g` | Same (standard Ex workflow) |
| Clear search highlight | `SPC s c` | `<Esc>` | LazyVim clears on Esc |

## Which-Key

Press `<leader>` (Space) and wait — which-key shows available bindings grouped by category, similar to Spacemacs.

Key groups:
- `<leader>f` — File / Find / Projects
- `<leader>g` — Git
- `<leader>b` — Buffers
- `<leader>c` — Code / LSP
- `<leader>s` — Search
- `<leader>w` — Windows
- `<leader>q` — Sessions / quit
- `<leader>h` — Harpoon working set
- `<leader>x` — Diagnostics / Trouble
- `<leader>u` — UI toggles
- `<leader>S` — Spell (replaces LazyVim's scratch-select binding)
- `<leader>a` — AI / Claude Code
- `<leader>d` — Debug (nvim-dap)
- `<leader><tab>` — Tabs (the closest analog to Spacemacs layouts)

## Custom Additions

| Action | Keybinding | Notes |
|--------|-----------|-------|
| Insert date | `<localleader>oc` | Inserts "Mon DD, YYYY" in `tex`/`org` buffers, matching the current Spacemacs major-mode date habit |
| Markdown preview | `<leader>cp` | `:LivePreview start` (live-preview.nvim), markdown buffers only. Browser-based analog of Spacemacs `grip-mode` (`,cg`) |

## Not ported from Spacemacs / `.vimrc`

These bindings exist in `.spacemacs` / `jal-functions.el` / `.vimrc` and have
**no** counterpart in this Neovim config. They are listed so the gap is
explicit rather than surprising.

| Source | Binding | What it did | Status here |
|---|---|---|---|
| `jal-functions.el` (latex-mode) | `,jn` / `,jp` | Next / previous LaTeX section | Not ported. VimTeX's own `]]` / `[[` section motions cover this |
| `jal-functions.el` (latex-mode) | `,jj` | `helm-imenu` | Not ported; nearest is `<leader>ss` (LSP symbols, needs texlab attached) |
| `jal-functions.el` (markdown/gfm) | `,M` | Compile the mermaid block at point | Not ported — mermaid is an explicit non-goal (`docs/archive/2026-03-23-neovim-support-design.md`) |
| `jal-functions.el` (mermaid-mode) | `,c` / `,b` / `,r` / `,o` / `,d` | mermaid compile / buffer / region / browser / doc | Not ported — same non-goal; no mermaid-mode analog |
| `.spacemacs` (markdown) | `,cg` | `grip-mode` GitHub-flavored preview | Replaced, not ported key-for-key: `<leader>cp` (live-preview.nvim) |
| `.vimrc` | `<C-p>` | `:Files` (fzf) | Not ported; `<leader>ff` is the picker here |
| `.vimrc` | `ga` | `vim-easy-align` | Not ported (plugin not installed) |
| `.vimrc` | `;m` | Replace the character under the cursor with a space | Not ported (`r<Space>` does the same) |
| `.vimrc` | cmdline `<C-h/j/k/l>`, `<C-^>`, `<C-$>` | Readline-ish command-line motions | Not ported; Neovim's default cmdline motions apply |
| `.vimrc` (tex buffers) | `$` / `0` / `^` -> `g$` / `g0` / `g^` | Screen-line motions in wrapped TeX | Not ported. `j` / `k` do respect wrapped lines (`config/keymaps.lua`), but `$`/`0`/`^` do not |

Also note: `.vimrc` has no `<Up>` / `<Down>` maps at all — only `j` / `k` get
the wrap-aware treatment there. LazyVim's own defaults map both `j`/`k` and
`<Up>`/`<Down>` to `gj`/`gk` (v:count == 0), with no `&wrap` guard on either.
This config overrides `j` / `k` to add the `&wrap` check (`config/keymaps.lua`)
but leaves `<Up>` / `<Down>` on LazyVim's unguarded default, so the arrow keys
disagree with `j` / `k` when `&wrap` is off.

## Tips for Spacemacs Users

1. **Leader is the same** — Space still drives discovery.
2. **Snacks picker/explorer replace the old Telescope/Neo-tree assumptions** in earlier drafts of this branch.
3. **Which-key is your friend** — press Space and read the popup.
4. **`:` commands still work** — `:w`, `:q`, `:wq`, `:%s` are available through the usual Ex command line.
5. **Sessions are the workspace story here** — think project picker + persistence first; tmux is optional.
6. **Harpoon 2 is a working-set helper** — use it if you like curated hot files; ignore it if you prefer picker/buffer flows.
7. **Mason manages tool installs** — run `:Mason` to inspect/update language servers and related tools.
8. **Lazy manages plugins** — run `:Lazy` to inspect/update plugins.

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
| `]j` | Next cell |
| `[j` | Previous cell |
| `]J` | Last cell |
| `[J` | First cell |
| `aj` | Around cell textobject (incl. marker) |
| `ij` | Inside cell textobject (code only) |

These used to be `]]` / `[[` (next/prev cell) and `]C` / `[C` (last/first
cell). They were moved to `]j` / `[j` / `]J` / `[J` because the maps are
installed in every Python buffer, cell markers or not, and `]]` / `[[` were
shadowing LazyVim's LSP Next/Prev Reference maps. `]]` / `[[` now navigate
document-highlight references again as LazyVim intends.

### Cheatsheet popup

`,?` in a Python/ipynb buffer shows the above in a floating window.

### Spacemacs translation

| Spacemacs | Neovim here |
|---|---|
| `SPC m s b` (send buffer) | `,jf` |
| `SPC m s f` (send function) | visual-select then `,js` |
| `SPC m s r` (send region) | visual-select then `,js` |
| `SPC m s i` (start/switch to REPL) | `,jo` (focus) / `,jt` (toggle window) |
| *(new)* | `,jj` = run cell (was not a Spacemacs verb) |

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

The `ai.claudecode` extra also binds a normal-mode `<leader>as`
("Add file" / `ClaudeCodeTreeAdd`), but it is filetype-gated to `NvimTree`,
`neo-tree` and `oil` buffers. None of those are installed here — the file tree
is the Snacks explorer — so that binding never fires. Use `<leader>ab` to add
the current buffer instead.

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

LazyVim's Snacks picker also claims `<leader>gd`, `<leader>gD` and
`<leader>gS` by default. This config disables all three on the Snacks side
(`nvim/lua/plugins/git.lua`) so `gd`/`gD` are unambiguously Diffview and `gS`
is Octo search; the Snacks git stash picker is re-homed on `<leader>gz`.

### Status / stage / commit (group `<leader>g` — "git")

| Keys | Action |
|---|---|
| `<leader>gg` | Open Neogit status |
| `<leader>gG` | Lazygit (cwd) — LazyVim default, unchanged |
| `<leader>gc` | Neogit commit popup |
| `<leader>gl` | Neogit log popup |
| `<leader>gL` | Git Log (cwd) — Snacks picker, LazyVim default |
| `<leader>gr` | Neogit pull popup |
| `<leader>gP` | Neogit push popup |
| `<leader>gz` | Git stash picker (Snacks) — re-homed off `<leader>gS`, which is Octo search |

### Diff / file history

| Keys | Action |
|---|---|
| `<leader>gd` | Diffview (working tree vs HEAD) |
| `<leader>gD` | Diffview (`origin/HEAD...HEAD`) |
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
| `SPC g s` (Magit status) | `<leader>gg` |
| `SPC g c c` (Magit commit) | `<leader>gc` |
| `SPC g l l` (Magit log) | `<leader>gl` |
| `SPC g f f` (Magit pull) | `<leader>gr` |
| `SPC g P p` (Magit push) | `<leader>gP` |
| `SPC g f h` (file hunk stage) | `<leader>ghs` |
| Forge issues — reached from the Magit status buffer (`SPC g s`), where Forge adds Issues/Pull Requests sections and its own dispatch transient. There is no `SPC g h *` leader key for this | `<leader>gi` (list) / `<leader>gI` (search) |
| Forge pull requests — same: from Magit status, not a leader key | `<leader>gp` (list) |
| `SPC d d` (run / continue) | `<leader>dc` |
| `SPC d b` (toggle breakpoint) | `<leader>db` |
| `SPC d i` (step into) | `<leader>di` |
| `SPC d o` (step over) | `<leader>dO` |
| `SPC d r` (REPL) | `<leader>dr` |

## Multi-cursor (vim-visual-multi)

| Keys | Mode | Action |
|---|---|---|
| `<C-n>` | normal / visual | Start session; select word / range under cursor. Press again to add next match. |
| `<M-Up>` / `<M-Down>` | normal | Add a cursor above / below |
| `<S-Left>` / `<S-Right>` | VM | Extend all cursors' selection |
| `n` / `N` | VM | Next / previous match |
| `q` | VM | Skip current match, jump to next |
| `Q` | VM | Remove the current cursor |
| `<Esc>` | VM | Exit multi-cursor mode |

vim-visual-multi's upstream default for add-cursor-above/below is
`<C-Up>` / `<C-Down>`. Those are LazyVim's window-height resize keys, so this
config remaps `g:VM_maps` to `<M-Up>` / `<M-Down>`
(`nvim/lua/plugins/visual-multi.lua`). Both sides survive: `<C-Up>` /
`<C-Down>` still resize the window, `<M-Up>` / `<M-Down>` add cursors.

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

### `<leader>S` — spell group

This config takes `<leader>S` as a `+spell` prefix, loosely mirroring the
Spacemacs spell-checking layer's `SPC S`. LazyVim's default `<leader>S`
(Snacks scratch-buffer select) is disabled to free the prefix
(`nvim/lua/plugins/spell.lua`); the scratch picker is still reachable as
`:lua Snacks.scratch.select()`.

| Keys | Action | Raw Vim key |
|---|---|---|
| `<leader>Sb` | Enable spell for the buffer (`en_us`) | `:setlocal spell spelllang=en_us` |
| `<leader>St` | Toggle spell for the buffer | `:setlocal spell!` |
| `<leader>Sd` | Set dictionary — prompts for `spelllang` | `:setlocal spelllang=...` |
| `<leader>Sn` / `<leader>SN` | Next / previous misspelling | `]s` / `[s` |
| `<leader>Ss` | Suggest corrections | `z=` |
| `<leader>Sa` | Add word to the personal dictionary | `zg` |
| `<leader>Sw` | Mark word as wrong | `zw` |
| `<leader>Su` | Undo the last add/mark | `zug` |
| `<leader>us` | Toggle spelling (LazyVim UI-toggles group) | |

The underlying `]s` / `[s` / `z=` / `zg` / `zw` keys all still work directly.

### Deviations from Spacemacs `SPC S`

- `Ss` suggests corrections (`z=`); Spacemacs uses `SPC S c` for
  flyspell-correct-word and `SPC S s` for correct-at-point.
- `Sb` *enables* spell for the buffer; Spacemacs `SPC S b` runs
  `flyspell-buffer` over an already-enabled buffer.
- `St` toggles spell here; Spacemacs toggles flyspell under `SPC t S`.
- `SN` (previous misspelling) has no Spacemacs `SPC S` equivalent.
- `Sa` / `Sw` / `Su` have no Spacemacs `SPC S` equivalent — flyspell manages
  the personal dictionary differently.
- Spacemacs `SPC S r` (flyspell-region) has no counterpart here.
- The personal word list is Neovim's own spellfile under
  `~/.local/share/nvim/site/spell/`; it is not shared with aspell/`~/.aspell.en.pws`.

## Snippets (blink.cmp)

There is **no LuaSnip** in this config. LazyVim 16 uses **blink.cmp**, which
reads VSCode-style snippet packages itself. This repo adds its snippets in
`nvim/snippets/` (with `nvim/snippets/package.json`), ported from the
Yasnippet sources under `snippets/` so the same triggers work in both
Spacemacs and Neovim.

Current ported set (filetype `tex`):

| Trigger | Expansion |
|---|---|
| `al*` | `\begin{align*} ... \end{align*}` |
| `eq*` | `\begin{equation*} ... \end{equation*}` |
| `secc` | `\section*{...}` |
| `subb` | `\subsection*{...}` |
| `i` | `\textit{...}` |
| `u` | `\underline{...}` |

Type the trigger in insert mode; the snippet shows up in the blink.cmp
completion menu, and **`<Enter>`** accepts it (LazyVim configures blink with
the `enter` keymap preset). `<Tab>` jumps to the *next placeholder* once a
snippet is active — it is not the expansion key. `<C-Space>` opens the menu
manually. `friendly-snippets` provides additional `tex` snippets alongside
these.
