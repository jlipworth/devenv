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
- `<leader>gg` — lazygit
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
| Save file | `SPC f s` | `<leader>w` or `:w` | |
| Command history | `SPC SPC` | `<leader>:` | Commands live at `<leader>sC` |

## Windows and Splits

| Action | Spacemacs | LazyVim | Notes |
|--------|-----------|---------|-------|
| Split vertical | `SPC w v` | `<leader>wv` or `<C-w>v` | |
| Split horizontal | `SPC w s` | `<leader>ws` or `<C-w>s` | |
| Close window | `SPC w d` | `<leader>wd` or `<C-w>c` | |
| Switch window | `SPC w w` | `<C-w>w` | |
| Move to window | `SPC w h/j/k/l` | `<C-h/j/k/l>` | LazyVim default |

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

| Action | Spacemacs | LazyVim | Notes |
|--------|-----------|---------|-------|
| Git status | `SPC g s` | `<leader>gg` | Opens lazygit |
| Git blame | `SPC g b` | `<leader>gb` | Inline blame |
| Git diff | `SPC g d` | `<leader>gd` | Hunk diff picker |

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

## Custom Additions

| Action | Keybinding | Notes |
|--------|-----------|-------|
| Insert date | `<localleader>oc` | Inserts "Mon DD, YYYY" in `tex`/`org` buffers, matching the current Spacemacs major-mode date habit |

## Tips for Spacemacs Users

1. **Leader is the same** — Space still drives discovery.
2. **Snacks picker/explorer replace the old Telescope/Neo-tree assumptions** in earlier drafts of this branch.
3. **Which-key is your friend** — press Space and read the popup.
4. **`:` commands still work** — `:w`, `:q`, `:wq`, `:%s` are available through the usual Ex command line.
5. **Sessions are the workspace story here** — think project picker + persistence first; tmux is optional.
6. **Harpoon 2 is a working-set helper** — use it if you like curated hot files; ignore it if you prefer picker/buffer flows.
7. **Mason manages tool installs** — run `:Mason` to inspect/update language servers and related tools.
8. **Lazy manages plugins** — run `:Lazy` to inspect/update plugins.
