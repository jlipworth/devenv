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
├── build_emacs30.sh         # Emacs compilation
├── prereq_packages.sh       # Language server installation
├── linking_script.sh        # Symlinks and fonts
├── common_utils.sh          # Shared utilities
├── versions.conf            # Pinned versions (Emacs, GCC)
├── requirements.txt         # Python packages (Renovate-tracked)
├── renovate.json            # Dependency update config
├── .spacemacs               # Spacemacs configuration
├── .vimrc                   # Vim configuration
├── .shell_aliases           # CLI tool aliases
├── brewfiles/               # Per-layer Homebrew packages
│   ├── Brewfile.cli_tools
│   ├── Brewfile.emacs-30
│   └── ...
├── good_fonts/              # Nerd Fonts (Meslo, DejaVu, SourceCodePro)
├── snippets/                # Yasnippets templates
├── ci/                      # CI Docker image
├── docs/                    # Documentation
│   ├── ALIASES.md           # Shell aliases reference
│   ├── BACKLOG.md           # Personal TODO tracking
│   ├── DEPENDENCIES.md      # Dependency management guide
│   ├── FUTURE_DEPLOYMENT_WORK.md  # Nix/Docker/Ansible plans
│   ├── MACOS_CI_TODO.md     # macOS CI setup (future work)
│   └── SSH_SETUP.md         # SSH key setup quick reference
└── .claude/commands/        # Claude Code custom commands
```

## Documentation

| File | Purpose |
|------|---------|
| [docs/ALIASES.md](docs/ALIASES.md) | Shell aliases for modern CLI tools |
| [docs/BACKLOG.md](docs/BACKLOG.md) | Personal TODO tracking |
| [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md) | Dependency management and Renovate |
| [docs/FUTURE_DEPLOYMENT_WORK.md](docs/FUTURE_DEPLOYMENT_WORK.md) | Future Nix/Docker/Ansible migration |
| [docs/MACOS_CI_TODO.md](docs/MACOS_CI_TODO.md) | macOS CI setup guide |
| [docs/SSH_SETUP.md](docs/SSH_SETUP.md) | SSH key setup quick reference |

## Key Patterns

- **OS detection**: `$OS` = "Darwin" or "Linux"
- **Package managers**: `$INSTALL_CMD`, `$PIP_CMD`, `$NODE_CMD`
- **Function naming**: `install_*_prereqs()` for each layer
- **Version pinning**: `versions.conf` sourced by scripts

## Testing

```bash
emacs --version              # Should show 30.1
```
