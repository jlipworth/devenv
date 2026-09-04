# CLAUDE.md

Guidance for Claude Code when working with this repository.

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

## Directory Structure

```
GNU_files/
├── makefile                 # Main entry point
├── bootstrap.sh             # Initial system bootstrap
├── build_emacs30.sh         # Emacs compilation
├── build_neovim.sh          # Neovim source build (NEOVIM_PREFIX, NEOVIM_FORCE_REBUILD)
├── prereq_packages.sh       # Language server installation
├── common_utils.sh          # Shared utilities
├── update_dependencies.sh   # Dependency update helper
├── versions.conf            # Pinned versions (Emacs, GCC, Node, Alacritty, Neovim target + minimum)
├── requirements.txt         # Python packages (Renovate-tracked)
├── renovate.json            # Dependency update config
├── .spacemacs               # Spacemacs configuration
├── jal-functions.el         # Custom Emacs Lisp helpers
├── .vimrc                   # Vim configuration
├── nvim/                    # LazyVim config (lua/config, lua/plugins, lua/jupyter, snippets, lazy-lock.json)
├── .shell_aliases           # CLI tool aliases
├── .blerc                   # Bash Line Editor config
├── .tmux.conf.local         # tmux local overrides (oh-my-tmux)
├── alacritty.toml           # Alacritty terminal config (WSL-oriented)
├── alacritty.windows.toml   # Alacritty terminal config for Windows
├── starship.toml            # Starship prompt config
├── .pre-commit-config.yaml  # Pre-commit hooks
├── .shellcheckrc            # ShellCheck settings
├── brewfiles/               # Per-layer Homebrew packages
│   ├── Brewfile.c_cpp
│   ├── Brewfile.cli_tools
│   ├── Brewfile.docker
│   ├── Brewfile.emacs-30
│   ├── Brewfile.git
│   ├── Brewfile.javascript
│   ├── Brewfile.kubernetes
│   ├── Brewfile.latex
│   ├── Brewfile.neovim-build
│   ├── Brewfile.ocaml
│   ├── Brewfile.sql
│   ├── Brewfile.swift
│   └── Brewfile.terraform
├── ghostty/                 # Ghostty terminal config
├── good_fonts/              # Nerd Fonts (Meslo, DejaVu, SourceCodePro)
├── snippets/                # Yasnippets templates
├── ci/                      # CI Docker images + smoke scripts (neovim-smoke.sh)
├── tests/                   # Shell + Lua specs (tests/nvim/run_nvim_tests.sh)
├── .woodpecker/             # Woodpecker CI pipelines
├── docs/                    # Documentation
│   ├── ALIASES.md
│   ├── BASH_TO_ZSH_MIGRATION_RUNBOOK.md
│   ├── DEPENDENCIES.md
│   ├── FORGE_SETUP.md
│   ├── FUTURE_DEPLOYMENT_WORK.md
│   ├── MACOS_CI_TODO.md
│   ├── NEOVIM_KEYBINDINGS.md
│   ├── NO_ADMIN_SETUP.md
│   ├── SPACEMACS_PRODUCTIVITY.md
│   ├── SSH_SETUP.md
│   └── UV_MIGRATION_RUNBOOK.md
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
