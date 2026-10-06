# AGENTS.md

Guidance for coding agents (Codex, Claude Code) working in this repository.
`CLAUDE.md` is a symlink to this file.

## Overview

Automated setup scripts for Emacs 30.2 + Spacemacs with language server support. Supports macOS and Linux (Debian/Ubuntu).

Also provisions Neovim (pinned source build) with a LazyVim config in `nvim/`, kept at rough parity with the Spacemacs layers.

## Quick Start

```bash
make full-setup        # Complete bootstrap
make spacemacs         # Build Emacs only
make prereq-layers-all # Install all language servers
make neovim            # Build pinned Neovim + link the LazyVim config
make neovim-test       # Headless Neovim Lua specs (tests/nvim)
```

## Key Patterns

- **OS detection**: `$OS` = "Darwin" or "Linux"
- **Package managers**: `$INSTALL_CMD`, `$PIP_CMD`, `$NODE_CMD`
- **Function naming**: `install_*_prereqs()` for each layer
- **Version pinning**: `versions.conf` sourced by scripts. Neovim pins both a
  target (`NEOVIM_VERSION`) and a floor (`NEOVIM_MIN_VERSION`, the version
  VimTeX requires); both accept an environment override
- **Neovim install mode**: `NEOVIM_INSTALL_MODE=source|package` selects between
  `build_neovim.sh` and the pinned GitHub release download (`make neovim-package`,
  the NO_ADMIN path). `ci/neovim-smoke.sh` uses its own `NVIM_INSTALL_MODE`
- **Neovim config**: LazyVim extras are imported from `nvim/lua/config/lazy.lua`
  only — importing them from `nvim/lua/plugins/` trips LazyVim's import-order
  warning. `nvim/lazy-lock.json` is tracked; commit lockfile changes deliberately
