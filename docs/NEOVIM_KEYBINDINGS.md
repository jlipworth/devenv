# Neovim (LazyVim) Keybinding Reference

Quick reference for Spacemacs users transitioning to Neovim with LazyVim.
Leader key is Space (same as Spacemacs).

## Core Navigation

| Action | Spacemacs | LazyVim | Notes |
|--------|-----------|---------|-------|
| Escape | `jk` | `jk` | Custom (config/keymaps.lua) |
| Find file | `SPC f f` | `<leader>ff` | Telescope |
| Recent files | `SPC f r` | `<leader>fr` | Telescope |
| Grep project | `SPC /` | `<leader>sg` | Telescope live grep |
| File explorer | `SPC f t` | `<leader>e` | Neo-tree |
| Buffer list | `SPC b b` | `<leader>fb` | Telescope buffers |
| Switch buffer | `SPC b n/p` | `[b` / `]b` | Previous/next buffer |
| Close buffer | `SPC b d` | `<leader>bd` | |
| Save file | `SPC f s` | `<leader>w` or `:w` | |
| Command palette | `SPC SPC` | `<leader>:` | Telescope commands |

## Windows and Splits

| Action | Spacemacs | LazyVim | Notes |
|--------|-----------|---------|-------|
| Split vertical | `SPC w v` | `<leader>wv` or `<C-w>v` | |
| Split horizontal | `SPC w s` | `<leader>ws` or `<C-w>s` | |
| Close window | `SPC w d` | `<leader>wd` or `<C-w>c` | |
| Switch window | `SPC w w` | `<C-w>w` | |
| Move to window | `SPC w h/j/k/l` | `<C-h/j/k/l>` | LazyVim default |

## Git

| Action | Spacemacs | LazyVim | Notes |
|--------|-----------|---------|-------|
| Git status | `SPC g s` | `<leader>gg` | Opens lazygit |
| Git blame | `SPC g b` | `<leader>gb` | Inline blame |
| Git diff | `SPC g d` | `<leader>gd` | Diffview |
| Next hunk | `] h` | `]h` | |
| Prev hunk | `[ h` | `[h` | |

## LSP

| Action | Spacemacs | LazyVim | Notes |
|--------|-----------|---------|-------|
| Go to definition | `g d` | `gd` | Same |
| Go to references | `g r` | `gr` | Same |
| Hover docs | `K` | `K` | Same |
| Rename symbol | `SPC l r` | `<leader>cr` | |
| Code action | `SPC l a` | `<leader>ca` | |
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
| Search and replace | `:%s/old/new/g` | `:%s/old/new/g` | Same (Vim native) |
| Clear search highlight | `SPC s c` | `<Esc>` | LazyVim clears on Esc |

## Which-Key

Press `<leader>` (Space) and wait — which-key shows all available bindings grouped by category. This works the same way as Spacemacs's SPC menu.

Key groups:
- `<leader>f` — File/Find
- `<leader>g` — Git
- `<leader>b` — Buffers
- `<leader>c` — Code (LSP)
- `<leader>s` — Search
- `<leader>w` — Windows
- `<leader>x` — Diagnostics/Trouble
- `<leader>u` — UI toggles

## Custom Additions

| Action | Keybinding | Notes |
|--------|-----------|-------|
| Insert date | `<leader>id` | Inserts "Mon DD, YYYY" (matches Spacemacs `,oc`) |

## Tips for Spacemacs Users

1. **Leader is the same** — Space key works identically as the leader
2. **Evil mode is NOT installed** — LazyVim uses native Vim keybindings. If you used Spacemacs Evil mode, the motions (`hjkl`, `ciw`, `dd`, etc.) are identical
3. **Which-key is your friend** — press Space and read the popup, just like Spacemacs
4. **`:` commands still work** — `:w`, `:q`, `:wq`, `:%s` all work exactly as in Vim
5. **Telescope replaces Helm** — fuzzy finding works similarly, just different keybindings
6. **Mason manages LSPs** — run `:Mason` to see/install/update language servers
7. **Lazy manages plugins** — run `:Lazy` to see/update/install plugins
