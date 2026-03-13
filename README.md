# devenv

![CI](https://img.shields.io/github/checks-status/jlipworth/devenv/master)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue)
![Emacs](https://img.shields.io/badge/Emacs-30.1-purple?logo=gnu-emacs)
![License](https://img.shields.io/github/license/jlipworth/devenv)

Personal Emacs build, dotfiles, and fonts.

Automated setup for Emacs 30.1 with Spacemacs, language servers for 13+ languages, and cross-platform support (macOS and Linux).

## Features

- **Emacs 30.1** compiled from source with native compilation, tree-sitter, and Cairo
- **Spacemacs** configuration with Evil mode
- **Language servers**: Python, JavaScript/TypeScript, C/C++, SQL, Terraform, LaTeX, Docker, OCaml, and more
- **Modern CLI tools**: eza, bat, ripgrep, fd, fzf, zoxide, lazygit
- **Fonts**: Nerd Font versions of Meslo, DejaVu Sans Mono, Source Code Pro

## Quick Start

**One-liner install:**
```bash
curl -fsSL https://raw.githubusercontent.com/jlipworth/devenv/master/bootstrap.sh | bash
```

**Or manually:**
```bash
git clone https://github.com/jlipworth/devenv.git ~/GNU_files
cd ~/GNU_files
make full-setup

# Or individual components
make spacemacs          # Build Emacs 30.1 + Spacemacs
make linking-prereq     # Symlinks for configs and fonts
make prereq-layers-all  # All layer prerequisites (language servers, tooling, etc.)
```

## No-admin / work-WSL2 mode

For locked-down Linux or WSL2 machines, the scripts support a repo-specific flag:

```bash
NO_ADMIN=true make spacemacs
NO_ADMIN=true make system-prereq
```

This is a **best-effort no-admin mode** for this repo. It is not a standard system environment variable.

What it does:

- avoids attempting Linux system package installs in helper flows
- prefers existing Linuxbrew/Homebrew where available
- installs Emacs to `~/.local` on Linux by default
- skips or downgrades some privileged operations to warnings/manual steps

What is still **not** possible under `NO_ADMIN=true` unless already preinstalled or otherwise available:

- distro package manager installs via `apt`, `pacman`, or `dnf`
- WSL config changes under `/etc/wsl.conf`
- system-wide installs under `/usr/local`
- Terraform apt-repo/key setup under `/etc` and `/usr/share`
- any fallback path that still depends on root-owned system packages being present

Practical recommendation:

- use `NO_ADMIN=true` for work WSL2 or no-sudo environments
- prefer `make spacemacs` first
- expect `make full-setup` and `make system-prereq` to remain only partially successful unless Linuxbrew and other prerequisites are already available

## Individual Language Layers

```bash
make python     # pyright, debugpy, linters
make js         # typescript-language-server, prettier, eslint
make c_cpp      # clangd/LLVM
make sql        # sqls
make terraform  # terraform-ls
make latex      # texlab
make docker     # dockerfile-language-server, hadolint
make ocaml      # opam, merlin, utop
make whisper    # speech-to-text (Spacemacs whisper layer)
make cli_tools  # eza, bat, ripgrep, fd, fzf, zoxide, lazygit
```

## Requirements

**macOS:**
- Xcode Command Line Tools
- Homebrew

**Linux (Debian/Ubuntu):**
- apt package manager
- Homebrew on Linux (installed automatically for some packages)

## Documentation

| File                                         | Description                                |
|----------------------------------------------|--------------------------------------------|
| [CLAUDE.md](CLAUDE.md)                       | AI agent reference and directory structure |
| [docs/ALIASES.md](docs/ALIASES.md)           | Shell aliases for modern CLI tools         |
| [docs/BASH_TO_ZSH_MIGRATION_RUNBOOK.md](docs/BASH_TO_ZSH_MIGRATION_RUNBOOK.md) | Bash to zsh migration runbook |
| [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md) | Dependency management and Renovate         |
| [docs/plans/WORK_WSL2_ADMIN_PERMS_AUDIT.md](docs/plans/WORK_WSL2_ADMIN_PERMS_AUDIT.md) | Work WSL2 / no-admin audit and remaining blockers |

## License

[MIT](LICENSE)
