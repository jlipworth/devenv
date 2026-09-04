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
make neovim-package          # Neovim from the pinned GitHub release (no sudo)
make system-prereq           # Node, CLI tools, git credential helper
make prereq-layers-all       # language servers and tooling
make noadmin-setup           # full no-admin setup path
```

## Prerequisites

The repo's NO_ADMIN mode depends on **Linuxbrew** being available. Without it,
most Linux package installs will be skipped with a warning.

If Linuxbrew is not already installed, ask your admin to set up
`/home/linuxbrew/.linuxbrew` or install it into `~/.linuxbrew`. Then use the
brew binary from that install to add it to your shell:

```bash
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
# or, if installed under your home directory:
eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
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
| `make neovim`       | Conditional  | Source build via `build_neovim.sh` into `$NEOVIM_PREFIX` (default `~/.local/neovim`); the build toolchain (cmake, ninja, gettext, ...) comes from Linuxbrew, so this needs Linuxbrew under NO_ADMIN |
| `make neovim-package` | User-space | **The supported NO_ADMIN path.** `NEOVIM_INSTALL_MODE=package`; downloads the pinned Neovim release into `~/.local/bin` when no usable package manager exists |
| `make neovim-test`  | User-space   | Headless Lua specs in `tests/nvim`; needs only an `nvim` on PATH |

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
| `html_css`    | User-space   | Stub target; actual tooling comes from the JS layer |
| `docker`      | Admin-only   | Docker daemon access is external/system-level |
| `kubernetes`  | Conditional  | brew-first; fallback is admin-backed |
| `ocaml`       | Conditional  | brew-first; opam itself is user-space; opam sandboxing disabled (bwrap fails in containers/WSL) |
| `terraform`   | Conditional  | brew-first; apt repo fallback skipped under NO_ADMIN |
| `rust`        | User-space   | rustup + cargo entirely in user space |
| `swift`       | User-space   | Linuxbrew when present; otherwise Swiftly installs the Swift toolchain under the user account |
| `ai-tools`    | Conditional  | Mostly user-space; OpenCode uses Homebrew on macOS and its native installer on Linux |

### Standalone targets

| Target                | Status       | Notes |
|-----------------------|--------------|-------|
| `cli_tools_core`      | Conditional  | Core dev tools via brew |
| `cli_tools_system`    | Admin-only   | Printing, clipboard, libtool |
| `starship`            | Conditional  | brew or curl installer to `~/.local/bin` |
| `syntax-highlighting` | Conditional  | zsh plugins via brew; blesh needs gawk |
| `latex_tooling`       | Conditional  | texlab, aspell via brew; okular skipped under NO_ADMIN |
| `latex_distribution`  | Conditional  | User-local TeX Live under NO_ADMIN |

## Neovim under NO_ADMIN

The default Unix path (`make neovim`) builds the pinned Neovim from source.
That needs a C toolchain, cmake, ninja and gettext, which `build_neovim.sh`
installs with `sudo apt`/`pacman` on Linux unless Linuxbrew is present — so
under NO_ADMIN the source build only works on a machine that already has
Linuxbrew (or the toolchain).

**The supported NO_ADMIN path is `make neovim-package`**, which downloads the
pinned Neovim release from GitHub into `~/.local/bin/nvim` and then symlinks
`~/.config/nvim` to this repo's `nvim/` directory. Nothing touches system
paths.

| Variable | Default | Effect |
|---|---|---|
| `NEOVIM_INSTALL_MODE` | `source` | `package` selects the download path. `make neovim-package` sets it for you |
| `NEOVIM_PREFIX` | `~/.local/neovim` | Install prefix for the **source** build; `build_neovim.sh` also symlinks `~/.local/bin/nvim` to it |
| `NEOVIM_VERSION` | from `versions.conf` | Environment override of the pinned target version; honored by both `build_neovim.sh` and the package path |
| `NEOVIM_MIN_VERSION` | from `versions.conf` | Minimum acceptable version (the VimTeX floor); the package path fails rather than leaving an older Neovim in place |
| `NEOVIM_FORCE_REBUILD` | `false` | `true` rebuilds from source even when the pinned version is already installed at `$NEOVIM_PREFIX` |
| `DRY_RUN` | `false` | `build_neovim.sh` reads it from the environment as well as from its `--verify` / `--check` / `--dry-run` flags |
| `NVIM_INSTALL_MODE` | `source` | Read by `ci/neovim-smoke.sh` only, to pick between `make neovim` and `make neovim-package` |

Two related tools:

- **lazygit** (backs LazyVim's `<leader>gG`) has no distro package under
  NO_ADMIN on Debian. `install_lazygit` in `common_utils.sh` falls back to the
  upstream GitHub release tarball, extracted into `~/.local/bin`.
- **The `tree-sitter` CLI** (used to compile nvim-treesitter grammars) is
  installed only on the Homebrew/Linuxbrew path (`Brewfile.neovim-build`), the
  Arch path (`tree-sitter-cli` package), and via `npm -g tree-sitter-cli` when
  Node is present. On a NO_ADMIN Linux box with neither brew nor Node,
  nothing is installed and nvim-treesitter falls back to prebuilt parsers —
  `build_neovim.sh` logs a warning rather than failing.

## What still requires admin

These are inherently system-level and cannot be moved to user space:

- **WSL config** — `/etc/wsl.conf` modifications (manual instructions printed)
- **Printing** — CUPS/lpr integration
- **Docker runtime** — daemon access and container group membership
- **apt repo/key management** — HashiCorp, etc. (only in non-brew fallback paths)

## CI validation

The `noadmin` CI pipeline (`.woodpecker/noadmin.yml`) runs smoke tests in a
non-root Debian container with Linuxbrew pre-installed and no sudo. It validates:

- `cli_tools` — core tools install, system extras skipped
- `r` — R installs via Linuxbrew
- `latex_tooling` — texlab available
- `system-prereq` — Node present, syntax highlighting validated, starship present, ksshaskpass skipped
- `noadmin-neovim` — runs `ci/neovim-smoke.sh` with `NVIM_INSTALL_MODE=package`
  (so it exercises `make neovim-package`) and asserts the `NVIM v...` banner in
  the job log

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
