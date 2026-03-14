# NO_ADMIN Audit — March 2026

Archived audit and work log from the `claude/audit-admin-permissions-cdlXy`
branch. For current NO_ADMIN usage, see `docs/NO_ADMIN_SETUP.md`.

Date: 2026-03-13

## Original audit findings

### Areas that required admin before this refactor

#### `common_utils.sh` — package manager abstraction

All Linux package install/update commands used sudo:
- Debian/Ubuntu: `sudo apt install -y`, `sudo apt update -qq`
- Arch: `sudo pacman -S --needed --noconfirm`
- Fedora: `sudo dnf install -y`

#### `build_emacs30.sh` — Emacs build and install

- Linux build deps via `sudo apt` / `sudo pacman`
- `sudo make install` (system-wide `/usr/local` prefix)
- `sudo emacs --batch` for Org recompilation under system prefix

#### `prereq_packages.sh` — prerequisite layers

- WSL config: write to `/etc/wsl.conf`
- WSL browser integration: `sudo apt-get install wslu`
- Git credential helper: built in `/usr/share/...`, copied to `/usr/local/bin`
- texlab: installed to `/usr/local/bin`
- Terraform: apt repo/key setup under `/etc` and `/usr/share`

### Already user-space safe

- Repo clone/update (`bootstrap.sh`)
- Dotfiles/fonts/linking (`linking_script.sh`)
- Node via nvm, Python via pipx, Rust via rustup, uv curl installer
- Symlinks into `~/.config`, `~/.local/bin`, `~/.claude`, `~/.codex`
- Spacemacs clone into `~/.emacs.d`

### Not found in active code

No use of: `systemctl`, `service`, `mount`, `setcap`, `ldconfig`,
`update-alternatives`, or kernel module commands.

---

## Changes made on the branch

### Emacs build/install

- Default Linux install prefix changed to `$HOME/.local`
- `./configure` uses `--prefix="$EMACS_PREFIX"`
- `make install` without sudo when prefix is writable
- Org recompilation follows install prefix instead of hardcoded `/usr/local`

### Emacs Linux dependencies

- Linuxbrew-first dependency installation
- `brewfiles/Brewfile.emacs-30` expanded with Linux-only formulas:
  libgccjit, gtk+3, ncurses, libx11, libxft, libxpm, binutils

### npm globals

- User-local npm prefix (`~/.npm-global`) on Linux
- PATH includes `~/.local/bin`, `~/.npm-global/bin`, `~/go/bin`

### texlab

- Installs to `~/.local/bin` instead of `/usr/local/bin`

### Git credential helper

- Copies source to temp dir for build (avoids writing to `/usr/share/...`)
- Binary lands in `~/.local/bin`
- Prefers brew libsecret, falls back to apt, skips under NO_ADMIN

### Terraform

- Linuxbrew-first for terraform, terraform-ls, ansible, jq
- apt repo fallback skipped under NO_ADMIN

### WSL helpers

- `setup_wsl_config` checks writability, prints manual instructions if blocked
- `install_wsl_utils` prefers brew, skips apt under NO_ADMIN

### NO_ADMIN mode

- `common_utils.sh` supports `NO_ADMIN=true`
- `install_packages` skips all system package installs in that mode
- Homebrew detection via shared `find_brew_bin` helper

### CLI tools split

- `install_cli_tools_core` — developer tools (brew-first)
- `install_cli_tools_system` — printing/clipboard/libtool (skipped under NO_ADMIN)

### Whisper split

- `install_whisper_toolchain` — ffmpeg, cmake, sox (brew-first)
- `install_whisper_audio_integration` — PulseAudio/ALSA (skipped under NO_ADMIN)

### LaTeX improvements

- User-local TeX Live installation path on Linux under NO_ADMIN
- `install_latex_tooling` / `install_latex_distribution` split
- texlab arch-aware binary download

### Python under NO_ADMIN

- Uses uv for all tool installation
- Installs from requirements.txt into user space

### R support

- Linuxbrew R preferred on Linux
- languageserver installs to user library

---

## Remaining open items (as of 2026-03-13)

### Still admin-backed when brew is unavailable

- All `install_packages` callers fall back to sudo package managers
- Emacs dependency install falls back to apt/pacman
- WSL config still targets `/etc/wsl.conf`
- Terraform still has apt repo fallback path

### Future improvements identified

- Shell layer: finish brew-first cleanup for shellcheck/shfmt
- Python: make normal target user-space-first outside NO_ADMIN
- Review c_cpp, sql, kubernetes, terraform, ocaml for hidden system-package assumptions
- Consider `make user-setup` / `make system-setup` target split

---

## CI infrastructure added

- `ci/Dockerfile.noadmin` — non-root Debian image with Linuxbrew, no sudo
- `.woodpecker/noadmin.yml` — smoke tests for cli_tools, whisper, r, latex_tooling, system-prereq
- `ci/build-image.sh` — extended with `--image noadmin` support
- `.woodpecker/notify.yml` — noadmin pipeline wired into notifications
