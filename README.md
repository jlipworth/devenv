# devenv

![CI](https://img.shields.io/github/checks-status/jlipworth/devenv/master)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue)
![Emacs](https://img.shields.io/badge/Emacs-30.1-purple?logo=gnu-emacs)
![License](https://img.shields.io/github/license/jlipworth/devenv)

Personal editor environment, dotfiles, and fonts.

Automated setup for Emacs 30.1 with Spacemacs, plus opt-in Neovim support, language servers for 13+ languages, and cross-platform support on macOS and Linux.

## Features

- **Emacs 30.1** compiled from source with native compilation, tree-sitter, and Cairo
- **Spacemacs** configuration with Evil mode
- **Neovim** support as an opt-in install path via `make neovim`
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
make editor-symlinks    # Symlinks for .vimrc and .spacemacs
make prereq-layers-all  # All layer prerequisites (language servers, tooling, etc.)
```

The examples use `~/GNU_files`, but the repo can be cloned anywhere.

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
make neovim     # Install/configure Neovim (opt-in)
```

## Requirements

**macOS:**
- Xcode Command Line Tools
- Homebrew

**Linux:**
- Debian/Ubuntu and Arch paths are supported in scripts
- Homebrew on Linux is used for some packages and no-admin flows

## CI / Validation

CI is split across Woodpecker pipeline files under `.woodpecker/`.

- `build.yml` validates the Emacs build flow
- `layers.yml` validates language/editor layers, including the Neovim smoke path
- `noadmin.yml` covers non-sudo smoke tests
- `lint.yml` runs formatting and lint checks

Neovim coverage includes a Linux headless smoke script at `ci/neovim-smoke.sh`.
macOS validation is still manual for now.

## Documentation

| File                                         | Description                                |
|----------------------------------------------|--------------------------------------------|
| [CLAUDE.md](CLAUDE.md)                       | AI agent reference and directory structure |
| [docs/ALIASES.md](docs/ALIASES.md)           | Shell aliases for modern CLI tools         |
| [docs/BASH_TO_ZSH_MIGRATION_RUNBOOK.md](docs/BASH_TO_ZSH_MIGRATION_RUNBOOK.md) | Bash to zsh migration runbook |
| [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md) | Dependency management and Renovate         |
| [docs/MACOS_CI_TODO.md](docs/MACOS_CI_TODO.md) | macOS CI future work and gaps            |
| [docs/NEOVIM_KEYBINDINGS.md](docs/NEOVIM_KEYBINDINGS.md) | Neovim-specific shortcuts and notes |
| [docs/NO_ADMIN_SETUP.md](docs/NO_ADMIN_SETUP.md) | NO_ADMIN setup guide: target compatibility, prerequisites, troubleshooting |
| [docs/SSH_SETUP.md](docs/SSH_SETUP.md)       | SSH key setup on a new machine             |

## License

[MIT](LICENSE)
