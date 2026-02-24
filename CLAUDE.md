# CLAUDE.md

Guidance for Claude Code when working with this repository.

## Overview

Automated setup scripts for Emacs 30.1 + Spacemacs with language server support. Supports macOS and Linux (Debian/Ubuntu).

## Quick Start

```bash
make full-setup        # Complete bootstrap
make spacemacs         # Build Emacs only
make prereq-layers-all # Install all language servers
```

## Directory Structure

```
GNU_files/
├── makefile                 # Main entry point
├── bootstrap.sh             # Initial system bootstrap
├── build_emacs30.sh         # Emacs compilation
├── prereq_packages.sh       # Language server installation
├── linking_script.sh        # Symlinks and fonts
├── common_utils.sh          # Shared utilities
├── update_dependencies.sh   # Dependency update helper
├── versions.conf            # Pinned versions (Emacs, GCC)
├── requirements.txt         # Python packages (Renovate-tracked)
├── renovate.json            # Dependency update config
├── .spacemacs               # Spacemacs configuration
├── jal-functions.el         # Custom Emacs Lisp helpers
├── .vimrc                   # Vim configuration
├── .shell_aliases           # CLI tool aliases
├── .blerc                   # Bash Line Editor config
├── .tmux.conf.local         # tmux local overrides (oh-my-tmux)
├── alacritty.toml           # Alacritty terminal config
├── starship.toml            # Starship prompt config
├── tabby-config.yaml        # Tabby terminal config
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
│   ├── Brewfile.ocaml
│   ├── Brewfile.sql
│   └── Brewfile.terraform
├── ghostty/                 # Ghostty terminal config
├── good_fonts/              # Nerd Fonts (Meslo, DejaVu, SourceCodePro)
├── snippets/                # Yasnippets templates
├── ci/                      # CI Docker image
├── .woodpecker/             # Woodpecker CI pipelines
├── docs/                    # Documentation
│   ├── ALIASES.md
│   ├── BACKLOG.md
│   ├── BASH_TO_ZSH_MIGRATION_RUNBOOK.md
│   ├── DEPENDENCIES.md
│   ├── FORGE_SETUP.md
│   ├── FUTURE_DEPLOYMENT_WORK.md
│   ├── MACOS_CI_TODO.md
│   ├── SPACEMACS_PRODUCTIVITY.md
│   ├── SSH_SETUP.md
│   └── UV_MIGRATION_RUNBOOK.md
└── .claude/commands/        # Claude Code custom commands
```

## Key Patterns

- **OS detection**: `$OS` = "Darwin" or "Linux"
- **Package managers**: `$INSTALL_CMD`, `$PIP_CMD`, `$NODE_CMD`
- **Function naming**: `install_*_prereqs()` for each layer
- **Version pinning**: `versions.conf` sourced by scripts
