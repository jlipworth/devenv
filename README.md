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
make prereq-layers-all  # All language servers
```

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
| [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md) | Dependency management and Renovate         |

## License

[MIT](LICENSE)
