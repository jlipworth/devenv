# NO_ADMIN Setup Guide

How to use this repo without admin/sudo privileges — applicable to locked-down
WSL2 machines, shared Linux workstations, or any environment where `sudo` is
unavailable.

## Quick start

```bash
export NO_ADMIN=true
make editor-symlinks         # .vimrc + .spacemacs symlinks (always user-space)
make editor                  # fonts + vim-plug (always user-space)
make spacemacs               # build Emacs to ~/.local (needs Linuxbrew)
make system-prereq           # Node, CLI tools, git credential helper
make prereq-layers-all       # language servers and tooling
```

## Prerequisites

The repo's NO_ADMIN mode depends on **Linuxbrew** being available. Without it,
most Linux package installs will be skipped with a warning.

If Linuxbrew is not already installed, ask your admin to set up
`/home/linuxbrew/.linuxbrew` or install it into `~/.linuxbrew`. Then run:

```bash
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"
```

Other user-space toolchains used automatically:

| Tool     | Purpose                          | Install location      |
|----------|----------------------------------|-----------------------|
| Linuxbrew| System packages without sudo     | `/home/linuxbrew/...` |
| nvm      | Node.js version management       | `~/.nvm`              |
| uv       | Python tool installation         | `~/.local/bin`        |
| rustup   | Rust toolchain                   | `~/.cargo`            |
| opam     | OCaml package manager            | `~/.opam`             |

## How NO_ADMIN=true works

When `NO_ADMIN=true` is set:

- `install_packages` skips all `apt`/`pacman`/`dnf` calls on Linux
- Functions prefer Linuxbrew, then user-local binary downloads
- System paths (`/etc`, `/usr/local`, `/usr/share`) are not written to
- Clear warnings are logged for anything that was skipped
- If brew is unavailable, the script continues with whatever is already installed

## Target compatibility matrix

Legend:

- **User-space** — works without admin in any environment
- **Conditional** — works if Linuxbrew (or other user toolchain) is available
- **Admin-only** — requires sudo/admin; skipped with warning under NO_ADMIN

### Foundation targets

| Target              | Status       | Notes |
|---------------------|--------------|-------|
| `make editor-symlinks` | User-space | Symlinks `.vimrc` and `.spacemacs` |
| `make editor`         | User-space | Installs fonts to `~/.fonts`, sets up vim-plug |
| `make spacemacs`    | Conditional  | User-local Emacs build (`~/.local`); needs Linuxbrew for build deps |
| `make node-manual`  | User-space   | nvm installs to `~/.nvm` |

### `make system-prereq` substeps

| Substep               | Status       | Notes |
|------------------------|--------------|-------|
| `install_wsl_utils`    | Conditional  | Prefers brew; skips apt fallback under NO_ADMIN |
| `install_homebrew`     | Conditional  | Detects existing Linuxbrew; skips bootstrap under NO_ADMIN |
| `install_cli_tools`    | Conditional  | Core tools via brew; system extras (cups, xclip) skipped |
| `install_git_credential` | Conditional | Builds helper to `~/.local/bin`; needs libsecret headers |
| `install_askpass`      | Admin-only   | Skipped with warning under NO_ADMIN |
| `install_nodejs`       | User-space   | nvm-based; fully user-local |

### Language layer targets

| Target        | Status       | Notes |
|---------------|--------------|-------|
| `shell-layer` | Conditional  | brew-first for shellcheck/shfmt; bash-language-server via npm |
| `git-layer`   | Conditional  | Brewfile-based when brew exists |
| `yaml`        | Conditional  | npm global install; user-space with nvm |
| `markdown`    | Conditional  | Mix of brew and npm; mostly user-space with nvm |
| `completion`  | User-space   | Symlink only |
| `vimscript`   | Conditional  | npm global install |
| `latex`       | Conditional  | texlab via brew or binary download; TeX Live user-local install |
| `python`      | Conditional  | Uses uv under NO_ADMIN; installs from requirements.txt |
| `python-env`  | User-space   | uv + ipython/jupyterlab |
| `r`           | Conditional  | Linuxbrew R preferred; languageserver to user library |
| `c_cpp`       | Conditional  | brew-first for LLVM; fallback is admin-backed |
| `sql`         | Conditional  | brew-first for Go; sqls via `go install` (user-space) |
| `js`          | Conditional  | brew + npm globals; user-space with nvm |
| `html_css`    | User-space   | Piggybacks on JS layer |
| `docker`      | Admin-only   | Docker daemon access is external/system-level |
| `kubernetes`  | Conditional  | brew-first; fallback is admin-backed |
| `ocaml`       | Conditional  | brew-first; opam itself is user-space |
| `terraform`   | Conditional  | brew-first; apt repo fallback skipped under NO_ADMIN |
| `rust`        | User-space   | rustup + cargo entirely in user space |
| `ai-tools`    | Conditional  | Mostly user-space; npm globals depend on nvm setup |

### Standalone targets

| Target                | Status       | Notes |
|-----------------------|--------------|-------|
| `cli_tools_core`      | Conditional  | Core dev tools via brew |
| `cli_tools_system`    | Admin-only   | Printing, clipboard, libtool |
| `starship`            | Conditional  | brew or curl installer to `~/.local/bin` |
| `syntax-highlighting` | Conditional  | zsh plugins via brew; blesh needs gawk |
| `whisper`             | Conditional  | Toolchain via brew; audio integration skipped under NO_ADMIN |
| `whisper_toolchain`   | Conditional  | ffmpeg, cmake, sox via brew |
| `whisper_audio`       | Admin-only   | PulseAudio/PipeWire/ALSA integration |
| `latex_tooling`       | Conditional  | texlab, aspell via brew; okular skipped under NO_ADMIN |
| `latex_distribution`  | Conditional  | User-local TeX Live under NO_ADMIN |

## What still requires admin

These are inherently system-level and cannot be moved to user space:

- **WSL config** — `/etc/wsl.conf` modifications (manual instructions printed)
- **Printing** — CUPS/lpr integration
- **Audio backends** — PulseAudio/PipeWire/ALSA system integration
- **Docker runtime** — daemon access and container group membership
- **apt repo/key management** — HashiCorp, etc. (only in non-brew fallback paths)

## CI validation

The `noadmin` CI pipeline (`.woodpecker/noadmin.yml`) runs smoke tests in a
non-root Debian container with Linuxbrew pre-installed and no sudo. It validates:

- `cli_tools` — core tools install, system extras skipped
- `whisper` — toolchain installs, audio integration skipped
- `r` — R installs via Linuxbrew
- `latex_tooling` — texlab available
- `system-prereq` — Node, starship, askpass skipped

## Troubleshooting

### blesh (bash syntax highlighting) fails to build

blesh requires `gawk`. Under NO_ADMIN, `install_packages gawk` is skipped.
Fix: `brew install gawk`, then rerun `make syntax-highlighting` or `make cli_tools`.

### Git credential helper build fails

The helper builds from system source directories (`/usr/share/doc/git/...`).
If those don't exist, the build is skipped. Fix: `brew install libsecret` and
ensure brew's git contrib sources are available.

### Emacs configure fails

Missing build dependencies. Ensure Linuxbrew has all packages from
`brewfiles/Brewfile.emacs-30`. Run: `brew bundle --file=brewfiles/Brewfile.emacs-30`
