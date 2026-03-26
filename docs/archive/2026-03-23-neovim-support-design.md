# Neovim Support for devenv

**Date:** 2026-03-23
**Status:** Draft
**Branch:** `feature/neovim-support`

## Summary

Add cross-platform Neovim support to the devenv repo using LazyVim as the distribution. Neovim is an opt-in, explicitly requested target — it is never part of `full-setup`, `noadmin-setup`, or `prereq-layers-all`. The existing Spacemacs workflow remains the default and is not modified. Where Neovim mirrors editor behavior, the source of truth should be current `.spacemacs` conventions or explicit repo-local choices, not the legacy Vim config.

## Motivation

Temporary Windows machines reset regularly and have no admin rights. Spacemacs requires building Emacs from source and downloading hundreds of packages on first launch — impractical for ephemeral environments. Neovim + LazyVim provides a fast, self-bootstrapping editor that auto-installs plugins and LSP servers on first launch.

Secondary benefit: cross-platform Neovim config available on Linux/Mac machines as an alternative to Spacemacs when desired.

## Scope

### In scope

- LazyVim-based Neovim config in `nvim/` directory
- LSP/editor support: Python, JavaScript/TypeScript, YAML, JSON, TOML, Shell, SQL, Markdown, HTML/CSS, Tailwind, R, LaTeX, and PowerShell when `pwsh`/PowerShell is available
- Core features: git integration (lazygit), fuzzy finding (Snacks picker), file explorer (Snacks explorer), session restore (persistence.nvim), optional Harpoon 2 working-set jumps, which-key, completion, treesitter syntax highlighting
- Custom keybindings preserving current Spacemacs muscle memory (`jk` escape, `SPC` leader, `,` major-mode leader, which-key flow)
- `make neovim` target in makefile (explicit opt-in only)
- `install_neovim()` function in `prereq_packages.sh` (cross-platform)
- Neovim step added to `setup-dev-tools.ps1` (Windows)
- Keybinding reference doc: `docs/NEOVIM_KEYBINDINGS.md`

### Out of scope

- Replacing or modifying the Spacemacs workflow
- Org-mode, Whisper, DAP, Mermaid, or other Spacemacs-specific features
- Languages not yet carried over from the current Spacemacs setup (C/C++, Rust, OCaml, Terraform, Docker/Kubernetes, Ansible, Nginx, CSV, Vimscript layer parity)
- Neovim GUI (neovide, etc.)

## Design

### Config structure

```
nvim/
├── init.lua                  # LazyVim bootstrap (~10 lines, clones lazy.nvim and calls config.lazy)
└── lua/
    ├── config/
    │   ├── options.lua       # Editor defaults grounded in current Spacemacs habits and repo choices
    │   ├── keymaps.lua       # Custom keybindings (jk escape, Spacemacs-compatible leader maps)
    │   └── lazy.lua          # require("lazy").setup() call importing LazyVim + plugins dir
    └── plugins/
        ├── colorscheme.lua   # Theme config (tokyonight)
        ├── editor.lua        # Overrides for editor plugins (picker/search behavior, etc.)
        ├── harpoon.lua       # Optional Harpoon 2 working-set keymaps
        └── lang.lua          # Language extras imports + shell/html/powershell manual config
```

This follows LazyVim's standard directory convention. Files in `lua/config/` and `lua/plugins/` are auto-discovered.

### LazyVim extras activation

Extras are enabled programmatically via `import` statements in `lua/plugins/lang.lua` (version-control friendly, avoids conflicts with LazyVim's auto-managed `lazyvim.json`):

```lua
-- lua/plugins/lang.lua
return {
  { import = "lazyvim.plugins.extras.lang.python" },
  { import = "lazyvim.plugins.extras.lang.typescript" },
  { import = "lazyvim.plugins.extras.lang.yaml" },
  { import = "lazyvim.plugins.extras.lang.json" },
  { import = "lazyvim.plugins.extras.lang.markdown" },
  { import = "lazyvim.plugins.extras.lang.sql" },
  { import = "lazyvim.plugins.extras.lang.toml" },

  -- Shell + HTML/CSS + PowerShell (manual config)
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        bashls = {},
        html = {},
        cssls = {},
        emmet_ls = {},
        -- Enable only when pwsh/PowerShell is available on PATH
        powershell_es = {},
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "bash-language-server",
        "shellcheck",
        "html-lsp",
        "css-lsp",
        "emmet-ls",
        "powershell-editor-services",
      },
    },
  },
}
```

### config/lazy.lua contents

This file contains the `require("lazy").setup()` call that imports LazyVim and auto-discovers the `plugins/` directory:

```lua
require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    { import = "plugins" },
  },
  defaults = { lazy = false },
  checker = { enabled = true },
  performance = {
    rtp = {
      disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" },
    },
  },
})
```

### Key custom settings

**options.lua:**
- Relative line numbers enabled to match the current `.spacemacs` line-number preference
- `timeoutlen=200` to match current Spacemacs `evil-escape-delay`
- Any spacing/indent overrides should only exist when they can be traced to a current Spacemacs layer setting or explicit repo choice

**keymaps.lua:**
- `jk` mapped to Escape in insert mode (matching Spacemacs `evil-escape`)
- Wrapped-line movement should follow the current Spacemacs `evil-respect-visual-line-mode` habit rather than unconditional `gj`/`gk` remaps
- Major-mode-local additions should prefer `<localleader>` / `,` when mirroring current Spacemacs major-mode bindings

### Sessions / workspace story

Neovim does not provide Spacemacs-style layouts out of the box, so the practical workflow here is:

- **Snacks project picker** for switching repositories
- **persistence.nvim** for restoring per-project sessions
- **Harpoon 2** for an optional per-project working set / hot-file list
- **tmux** as an extra option on Unix/WSL/remote setups, not a baseline requirement

### Symlink strategy

The `nvim/` directory in the repo is symlinked to the platform config location:

| Platform | Symlink target |
|----------|---------------|
| Linux/Mac | `~/.config/nvim` → `$GNU_DIR/nvim` |
| Windows | `$env:LOCALAPPDATA\nvim` → `$GNU_DIR\nvim` |

The `install_neovim()` function must handle pre-existing `~/.config/nvim`:
- If it's a symlink: replace it
- If it's a directory: back it up (append timestamp), then create symlink
- Following the same pattern as `create_snippet_symlink()` in `prereq_packages.sh`

**Windows note:** Uses `New-Item -ItemType Junction` which works without admin for local paths. If the user's home directory is on a network share, junction will fail — the fallback is to copy the `nvim/` directory instead and note that manual sync is needed.

### Plugin/LSP auto-install behavior

On first launch, LazyVim + mason.nvim will:
1. Download and install all plugins (lazy.nvim handles this)
2. Download and install LSP servers (mason.nvim handles this)

This requires internet on first launch but no admin rights and no pre-installed tools beyond Neovim itself.

### Dependencies

- **lazygit** is required for `<leader>gg` (LazyVim's default git integration). `install_neovim()` should install it, or document that `make cli_tools_core` provides it. Since `neovim` is a standalone target, lazygit should be installed as part of it.

## Integration

### makefile

New target (opt-in only, never added to any existing composite target):

```makefile
neovim:
	@echo "Installing Neovim and configuring LazyVim..."
	@./prereq_packages.sh install_neovim
```

**Implementation notes:**
- Add `neovim` to the `.PHONY` declaration
- Add `neovim` to the `help` target output under "Other targets"
- Do NOT add `neovim` to `prereq-layers-all`, `full-setup`, or `noadmin-setup`

### prereq_packages.sh

New function `install_neovim()`:

- **Mac:** `brew install neovim lazygit`
- **Linux (brew available):** `brew install neovim lazygit`
- **Linux (no brew, no admin):** Download Neovim appimage to `~/.local/bin` (extract with `--appimage-extract` if FUSE unavailable). Install lazygit binary from GitHub releases.
- **Arch:** `install_packages neovim lazygit` (respects `NO_ADMIN` — falls through to brew/appimage path when `NO_ADMIN=true`)
- **Debian (no brew, no admin):** Same appimage path as above
- Creates `~/.config/nvim` symlink → `$GNU_DIR/nvim` (with backup handling for pre-existing directory)
- Does NOT install LSP servers (mason handles that on first launch)

**Implementation notes:**
- Add `install_neovim` to the `valid_functions` array in `main()`
- Do NOT add `install_neovim` to `install_all()`
- Add `NEOVIM_VERSION="0.11.6"` to `versions.conf` for the appimage download path

### setup-dev-tools.ps1 (Windows)

This file already exists at the repo root (created earlier in this session at `~/setup-dev-tools.ps1`; will be moved into the repo). New step added:

- Query the latest official Neovim release from GitHub
- Download the matching `nvim-win64.zip`, extract to `$env:LOCALAPPDATA\nvim-bin`, add to PATH
- Verify the installed Neovim version is at least the LazyVim minimum (`0.11.2`), and fail if not
- Clone devenv repo: `git clone https://github.com/jlipworth/devenv.git $env:USERPROFILE\GNU_files`
- Create junction: `New-Item -ItemType Junction -Path "$env:LOCALAPPDATA\nvim" -Target "$env:USERPROFILE\GNU_files\nvim"`

### docs/NEOVIM_KEYBINDINGS.md

Reference card mapping Spacemacs habits to LazyVim equivalents:

| Action | Spacemacs | LazyVim |
|--------|-----------|---------|
| Find file | `SPC f f` | `<leader>ff` |
| Grep project | `SPC /` | `<leader>sg` |
| File explorer | `SPC f t` | `<leader>e` |
| Projects | `SPC p l` / `SPC p p` | `<leader>fp` |
| Restore session | `SPC l l` / restart flows | `<leader>qs` / `<leader>ql` |
| Git status | `SPC g s` | `<leader>gg` (lazygit) |
| Buffer list | `SPC b b` | `<leader>fb` |
| Save file | `SPC f s` | `<leader>w` or `:w` |
| Close buffer | `SPC b d` | `<leader>bd` |
| Split vertical | `SPC w v` | `<leader>w` + `v` |
| Split horizontal | `SPC w s` | `<leader>w` + `s` |
| Switch window | `SPC w w` | `<C-w>w` |
| LSP go to def | `g d` | `gd` |
| LSP references | `g r` | `gr` |
| LSP rename | `SPC l r` | `<leader>cr` |
| LSP code action | `SPC l a` | `<leader>ca` |
| Which-key help | `SPC` (wait) | `<leader>` (wait) |
| Harpoon add file | n/a | `<leader>ha` |
| Harpoon menu | n/a | `<leader>hh` |
| Harpoon file 1-4 | n/a | `<leader>h1` ... `<leader>h4` |

## Constraints

- Neovim config must not require admin rights to use
- Neovim target must never be included in `full-setup`, `noadmin-setup`, or `prereq-layers-all`
- Existing legacy Vim config remains untouched and continues serving Vim/VSCode
- No modifications to any existing Spacemacs-related code
- Config should work offline after first launch (all plugins cached locally)

## Cleanup / Uninstall

To remove Neovim setup:
1. Remove config symlink: `rm ~/.config/nvim` (Linux/Mac) or remove junction on Windows
2. Remove plugin/mason data: `rm -rf ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim`
3. Optionally uninstall Neovim binary (`brew uninstall neovim` or remove appimage)

## Testing

- Fresh launch on Linux: `make neovim && nvim` — plugins and LSP servers auto-install
- Fresh launch on Windows: run `setup-dev-tools.ps1`, open `nvim` — same behavior
- Verify LSP works for each language: open a file of that type, run `:LspInfo`, confirm the correct server attaches, hover docs work (`K` on a symbol)
  - Python: Pyright/Ruff attach
  - TypeScript: vtsls attaches
  - YAML: yamlls attaches
  - JSON: jsonls attaches
  - Shell: bashls attaches
  - Markdown: marksman attaches
  - PowerShell: powershell_es attaches for `.ps1` when `pwsh`/PowerShell is available
- Verify keybindings: `jk` exits insert mode, `<leader>ff` opens the Snacks picker, `<leader>sg` greps project, `<leader>e` opens Snacks explorer, `<leader>gg` opens lazygit, and `<leader>qs` restores the session
- Verify no changes to `make full-setup` or `make noadmin-setup` behavior
- Verify `make help` shows the `neovim` target
