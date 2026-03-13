# Work WSL2 admin-permissions audit

Date: 2026-03-13

Purpose: capture the current repo areas that require elevated/admin permissions so they can be refactored toward user-space installs, especially for locked-down work WSL2 machines.

## Summary

The biggest admin blockers today are:

1. System package installs via `apt` / `pacman` / `dnf`
2. Emacs installation into `/usr/local`
3. Writes to `/etc`, `/usr/local`, `/usr/share`, and apt repo config locations

Large parts of the repo are already user-space friendly, but a few install paths still assume elevation.

---

## Starting from the Emacs build

Entry path:

- `makefile:23-26` → `make spacemacs`
- `build_emacs30.sh`

### Requires admin

- Linux build dependencies:
  - `build_emacs30.sh:66-80` → `sudo pacman ...`
  - `build_emacs30.sh:100-126` → `sudo apt ...`
- Emacs system install:
  - `build_emacs30.sh:285` → `sudo make install`
- Org recompilation under system prefix:
  - `build_emacs30.sh:291-299`
  - `build_emacs30.sh:297` → `sudo emacs --batch ...`

### User-space safe

- Download/extract Emacs source
- `./configure`
- `make -j...`
- Local verification of built Emacs
- Spacemacs clone into `~/.emacs.d`

### Suggested refactor

- Add `--prefix="$HOME/.local"` to Emacs configure
- Use plain `make install`
- Avoid post-install work under `/usr/local/share/emacs/...`

That would let the Emacs flow stay in user space, assuming dependencies are already available.

---

## Definitely requires admin today

### `common_utils.sh`

These make Linux package installation privileged by default:

- `common_utils.sh:58` → `sudo pacman -S --needed --noconfirm`
- `common_utils.sh:67` → `sudo pacman -S --noconfirm`
- `common_utils.sh:78` → `sudo apt install -y`
- `common_utils.sh:83` → `sudo apt update -qq`
- `common_utils.sh:85` → `sudo apt install --only-upgrade -y`
- `common_utils.sh:89` → `sudo dnf install -y`
- `common_utils.sh:94` → `sudo dnf makecache -q`
- `common_utils.sh:96` → `sudo dnf upgrade -y`
- `common_utils.sh:287` → `sudo apt install --only-upgrade -y "$package"`

### `build_emacs30.sh`

- `build_emacs30.sh:285` → `sudo make install`
- `build_emacs30.sh:297` → `sudo emacs --batch ...`

### `prereq_packages.sh`

- WSL config:
  - `prereq_packages.sh:78` → write `/etc/wsl.conf`
- WSL browser integration:
  - `prereq_packages.sh:89` → install `wslu` with `sudo apt-get`
- Git credential helper:
  - `prereq_packages.sh:173-174`
  - `prereq_packages.sh:180-181`
  - builds from `/usr/share/...` and copies into `/usr/local/bin`
- Debian texlab fallback:
  - `prereq_packages.sh:386-390`
  - installs into `/usr/local/bin`
- Terraform apt repo setup:
  - `prereq_packages.sh:642` → write `/usr/share/keyrings/hashicorp-archive-keyring.gpg`
  - `prereq_packages.sh:650` → write `/etc/apt/sources.list.d/hashicorp.list`
  - `prereq_packages.sh:653` → `sudo apt update -qq`

---

## Conditionally privileged / likely blockers on work WSL2

### Linuxbrew install

- `prereq_packages.sh:103-104`

This may or may not be okay depending on how Linuxbrew is installed. The current setup assumes `/home/linuxbrew/.linuxbrew`, which is outside the user home and may be blocked on a work machine.

### Any function that routes through `install_packages`

Examples:

- `install_shell_prereqs`
- `install_whisper_prereqs`
- `install_markdown_support`
- `install_latex_tools`
- `install_python_prereqs`
- `install_r_support`
- `install_c_cpp_prereqs`
- `install_sql_tools`
- `install_docker_support`
- `install_kubernetes_support`
- `install_ocaml_support`
- `install_terraform_support`
- `install_cli_tools`

On Linux these generally become privileged because `install_packages` uses `sudo`-backed package manager commands.

### Global npm installs

- `npm install -g ...`

These are okay if Node came from `nvm`, but may require admin if using system Node.

### Docker

- Installing Docker packages is privileged
- Using Docker may also depend on daemon/group access

---

## User-space safe today

### Repo/bootstrap

- `bootstrap.sh` clones/updates into `~/GNU_files`

### Dotfiles/fonts/linking

- `linking_script.sh`
  - symlinks into `$HOME`
  - fonts into `~/.fonts` or `~/Library/Fonts`
  - vim-plug into `~/.vim/...`

### User-local installers and home-dir setup

- Node via `nvm`
  - `prereq_packages.sh:112-159`
- Python via `pipx`
  - `prereq_packages.sh:400-441`
- Rust via `rustup`
  - `prereq_packages.sh:683-745`
- `uv` curl fallback and `uv tool install`
  - `prereq_packages.sh:1099-1114`
- Many symlinks into:
  - `~/.config`
  - `~/.local/bin`
  - `~/.claude`
  - `~/.codex`

---

## Not found in active repo code

Did not find active install/runtime code using:

- `systemctl`
- `service`
- `mount`
- `setcap`
- `ldconfig`
- `update-alternatives`
- kernel module commands

---

## Recommended refactor directions

### High priority

1. Make Emacs install user-local
   - `--prefix="$HOME/.local"`
   - no `sudo make install`

2. Stop installing helper binaries into `/usr/local/bin`
   - use `~/.local/bin` for:
     - `texlab`
     - `git-credential-libsecret` fallback helper

3. Gate all system modifications behind explicit opt-in
   - separate user-space setup from admin-required setup
   - especially for:
     - WSL config
     - apt repo/key setup
     - package manager installs

4. Prefer user-space distribution methods where practical
   - Linuxbrew if already available
   - user-local tarball/binary installs
   - `nvm`, `pipx`, `uv`, `rustup`, `opam`

### WSL2-specific

- Skip `setup_wsl_config` by default
- Avoid apt repo writes unless explicitly requested
- Assume `/etc` and `/usr/local` may be blocked

---

## Practical takeaway

Likely doable without admin:

- clone repo
- symlink configs
- install fonts in user dirs
- build Emacs from source
- run built Emacs locally
- install Spacemacs in `~/.emacs.d`
- use `nvm`, `pipx`, `rustup`, `uv`

Not currently doable without admin:

- `apt` / `pacman` / `dnf` installs
- system-wide Emacs install
- writes to `/etc/wsl.conf`
- writes to `/usr/local/bin`
- apt repo/key setup under `/etc` and `/usr/share`

---

## Follow-up

When the Claude branch is ready:

1. switch to that branch
2. compare changed install paths against this file
3. remove items that no longer require elevation
4. keep remaining blockers grouped as:
   - definitely privileged
   - conditional
   - user-space safe

---

## Status on branch: `claude/audit-admin-permissions-cdlXy`

Checked on: 2026-03-13

Recent branch commits:

- `34b74eb` — `Reduce sudo requirements for WSL2/no-admin environments`
- `a4ede1e` — `Add Linuxbrew path for all Emacs build deps (no sudo needed)`

### Improvements made on this branch

#### Emacs build/install

- `build_emacs30.sh` now defaults Linux installs to:
  - `EMACS_PREFIX="${HOME}/.local"`
- `./configure` now uses:
  - `--prefix="$EMACS_PREFIX"`
- install now uses plain `make install` when the prefix is writable
- Org recompilation now uses:
  - `${EMACS_PREFIX}/share/emacs/${EMACS_VERSION}/lisp/org`
  instead of hardcoded `/usr/local/...`

Impact:

- This removes the old always-system-wide Emacs install assumption on Linux.
- Emacs is now much closer to a true user-space install path.

#### Emacs Linux dependencies

- Linux Emacs dependency installation now prefers Linuxbrew when available
- `brewfiles/Brewfile.emacs-30` now includes Linux-only formulas for:
  - `libgccjit`
  - `gtk+3`
  - `ncurses`
  - `libx11`
  - `libxft`
  - `libxpm`

Impact:

- On machines with Linuxbrew already available, Emacs build dependencies can now avoid `apt`.

#### npm globals

- `common_utils.sh` now configures a Linux user-local npm prefix:
  - `~/.npm-global`
- PATH is updated to include:
  - `~/.local/bin`
  - `~/.npm-global/bin`
  - `~/go/bin`

Impact:

- `npm install -g ...` is less likely to require sudo on Linux.

#### texlab

- `prereq_packages.sh` now installs `texlab` into:
  - `~/.local/bin`
  instead of `/usr/local/bin`

#### Git credential helper

- `prereq_packages.sh` now copies `git-credential-libsecret` into:
  - `~/.local/bin`
  and configures Git to use that path

#### Terraform

- Linux path now prefers Linuxbrew for:
  - `terraform`
  - `terraform-ls`
  - `ansible`
  - `jq`
- HashiCorp apt repo setup remains only as a fallback

#### WSL helpers

- `setup_wsl_config` now checks writability first and prints manual instructions if it cannot write
- `install_wsl_utils` now prefers Homebrew first and warns if neither brew nor sudo is available

---

## Remaining blockers on branch: `claude/audit-admin-permissions-cdlXy`

### Still definitely privileged or still privilege-backed

#### Package manager abstraction still uses sudo on Linux

`common_utils.sh` still defines Linux package install/update commands as privileged:

- Debian/Ubuntu:
  - `sudo apt install -y`
  - `sudo apt update -qq`
  - `sudo apt install --only-upgrade -y`
- Arch:
  - `sudo pacman -S ...`
- Fedora:
  - `sudo dnf install -y`
  - `sudo dnf makecache -q`
  - `sudo dnf upgrade -y`

Impact:

- Any target that routes through `install_packages` remains admin-dependent on Linux unless it has been explicitly rewritten to prefer brew or other user-local methods.

#### WSL config still modifies `/etc/wsl.conf`

- `setup_wsl_config` is safer now, but the actual write target is still:
  - `/etc/wsl.conf`

Impact:

- Still admin-required unless the file is writable already.

#### Terraform fallback still writes system apt config

If brew is unavailable, Terraform setup still falls back to:

- `/usr/share/keyrings/hashicorp-archive-keyring.gpg`
- `/etc/apt/sources.list.d/hashicorp.list`
- `sudo apt update`

Impact:

- Still admin-required in fallback mode.

### Still conditional / still likely problematic on work WSL2

#### Emacs dependency fallback still uses apt/pacman

The branch improves Linux Emacs builds a lot, but only if brew already exists.

Fallback path still uses:

- `sudo apt ...`
- `sudo pacman ...`

Impact:

- Emacs is much improved for no-admin environments with brew, but still blocked without brew.

#### Linuxbrew installation itself may still be blocked

`install_homebrew()` still uses the official installer and adds:

- `/home/linuxbrew/.linuxbrew/bin`

Impact:

- This may still be blocked or unsuitable on locked-down work WSL2 machines.
- It is better than hardcoding apt for everything, but it is not guaranteed user-space safe in practice.

#### Git credential helper may still fail even without sudo

The branch removed `sudo`, but still builds from root-owned source trees:

- `/usr/share/doc/git/contrib/credential/libsecret`
- `/usr/share/git/credential/libsecret`

Impact:

- Copy target is now user-local, which is good.
- But the in-place `make` step may still fail if those directories are not writable or if the build wants to emit artifacts there.
- This item should be treated as improved but not fully resolved until tested.

### Targets likely still admin-dependent because they use `install_packages`

Unless separately rewritten, these still likely require admin on Linux:

- `install_shell_prereqs`
- `install_whisper_prereqs`
- `install_markdown_support`
- parts of `install_latex_tools`
- `install_python_prereqs`
- `install_r_support`
- `install_c_cpp_prereqs` fallback path
- `install_sql_tools` fallback path
- `install_docker_support` fallback path
- `install_kubernetes_support` fallback path
- `install_ocaml_support` fallback package-install path
- `install_cli_tools`

---

## Precise remaining-blockers checklist

Use this when reviewing future branch changes.

### Fully fixed on this branch

- [x] Emacs default Linux install prefix moved from system path to `~/.local`
- [x] Emacs Org recompilation path now follows install prefix
- [x] Linux Emacs deps prefer Linuxbrew
- [x] `texlab` target moved from `/usr/local/bin` to `~/.local/bin`
- [x] npm globals use user-local prefix on Linux
- [x] Terraform prefers Linuxbrew on Linux
- [x] WSL helper flows now degrade more gracefully when sudo is unavailable

### Improved but not fully resolved

- [ ] `install_homebrew()` still assumes Linuxbrew installation path/setup that may be blocked on work machines
- [ ] `install_git_credential()` still builds from `/usr/share/...` and may fail despite user-local output
- [ ] `install_wsl_utils()` still needs either brew or sudo
- [ ] `setup_wsl_config()` still ultimately modifies `/etc/wsl.conf`
- [ ] Emacs Linux build still falls back to sudo package installs when brew is absent
- [ ] Terraform Linux setup still falls back to sudo apt repo configuration when brew is absent

### Still mostly admin-backed

- [ ] `common_utils.sh` Linux package manager abstraction still uses sudo by default
- [ ] `install_packages()` callers remain admin-dependent unless given explicit brew/user-local alternatives
- [ ] `make system-prereq` still includes Linux-admin-backed flows
- [ ] `make full-setup` still includes many Linux-admin-backed subtargets

### Good next refactors

- [ ] Add a clearly separate “user-space only” install mode/target
- [ ] Make `install_homebrew()` detect and support a truly user-owned Homebrew path where possible
- [ ] Replace remaining `/usr/share/... -> make` credential-helper build with a copy-to-temp-and-build flow, if needed
- [ ] Convert more Linux package installs to brew-first or user-local binary installs
- [ ] Gate all `/etc` and apt-repo mutations behind explicit opt-in targets

---

## Local follow-up refactors after branch review

Checked on working tree: 2026-03-13

Additional local refactors made after reviewing `claude/audit-admin-permissions-cdlXy`:

### `NO_ADMIN` mode improvements

- `common_utils.sh` now supports:
  - `NO_ADMIN=true`
- In that mode, `install_packages` does not attempt Linux system package installs
- Instead it logs which packages were skipped

Impact:

- Aggregate targets can now degrade more gracefully on locked-down machines instead of immediately trying `sudo apt` / `sudo pacman`

### Homebrew detection improvements

- Added shared brew discovery helper in `common_utils.sh`
- `install_homebrew()` now:
  - detects brew in common locations
  - uses `brew shellenv` instead of hardcoding only `/home/linuxbrew/.linuxbrew/bin`
  - avoids automatic bootstrap when `NO_ADMIN=true`

Impact:

- Better support for existing Linuxbrew installs
- Less brittle PATH setup

### Git credential helper build flow

- `install_git_credential()` now copies the helper source tree into a temporary build directory
- It builds there instead of running `make` in `/usr/share/...`
- Final binary still lands in `~/.local/bin`

Impact:

- Removes the remaining likely write/build failure against root-owned source directories

### WSL / Terraform fallback behavior

- `setup_wsl_config()` now respects `NO_ADMIN=true` and prints manual instructions instead of trying privileged writes
- `install_wsl_utils()` now skips apt fallback when `NO_ADMIN=true`
- `install_terraform_support()` now skips apt-repo fallback when `NO_ADMIN=true`

Impact:

- Better best-effort behavior in locked-down WSL2 environments

### Emacs build fallback behavior

- `build_emacs30.sh` now uses shared brew discovery logic
- If Linuxbrew is not available and `NO_ADMIN=true`, it exits with a clear message instead of silently falling through to sudo-backed apt install

Impact:

- Makes no-admin behavior more explicit and predictable

### Python / shell / CLI / R / Whisper follow-up

- `install_python_prereqs()` now has a user-space path under `NO_ADMIN=true`
  - uses `uv`
  - installs tools from `requirements.txt` into user space
- `install_shell_prereqs()` now prefers Homebrew/Linuxbrew for:
  - `shellcheck`
  - `shfmt`
- `install_cli_tools()` now prefers Homebrew/Linuxbrew first on Linux for many base tools
- `install_r_support()` now prefers Homebrew/Linuxbrew on Linux before distro packages
- `install_whisper_prereqs()` now prefers Homebrew/Linuxbrew on Linux for core user-space tools
- `install_latex_tools()` now prefers Homebrew/Linuxbrew on Linux for user-space-accessible tooling

Impact:

- More primary install paths now begin in user space instead of starting with distro package managers
- Remaining blockers are increasingly about external system capabilities (audio stack, GUI viewers, full TeX distro, Docker daemon, etc.) rather than repo-local path choices

---

## Target-by-target matrix on branch: `claude/audit-admin-permissions-cdlXy`

Legend:

- **User-space friendly** = should work without admin in a well-prepared user-space environment
- **Conditional** = can work without admin, but only if prerequisites like Linuxbrew already exist
- **Admin-backed** = still likely to require sudo/admin on Linux

### `make spacemacs`

Definition:

- `makefile:23-26`
- runs `./build_emacs30.sh`

| Area | Status | Notes |
|---|---|---|
| Download Emacs source | User-space friendly | Happens in repo working tree |
| Configure Emacs | User-space friendly | Now uses `--prefix="$HOME/.local"` on Linux by default |
| Build Emacs | User-space friendly | Local compile in source tree |
| Install Emacs | Conditional | User-space if `~/.local` is writable; sudo only if prefix is unwritable or overridden to system path |
| Org recompilation | Conditional | Now follows install prefix; user-space if prefix is user-owned |
| Linux dependency install | Conditional | User-space if Linuxbrew exists; still admin-backed if it falls back to `apt` / `pacman` |
| Spacemacs clone into `~/.emacs.d` | User-space friendly | No admin needed |

#### Overall verdict for `make spacemacs`

- **Conditional**
- Good path for work WSL2 **if Linuxbrew is already available**
- Still blocked if the script falls back to Linux system package managers

### `make system-prereq`

Definition:

- `makefile:33-40`
- runs:
  - `install_wsl_utils`
  - `install_homebrew`
  - `install_cli_tools`
  - `install_git_credential`
  - `install_askpass`
  - `install_nodejs`

| Substep | Status | Notes |
|---|---|---|
| `install_wsl_utils` | Conditional | User-space if brew path works; otherwise still needs sudo apt |
| `install_homebrew` | Conditional | Useful direction, but current Linuxbrew install/setup may still be blocked on locked-down WSL2 |
| `install_cli_tools` | Admin-backed | Still routes through `install_packages` for Linux package installs |
| `install_git_credential` | Conditional | Output is now user-local, but build still occurs under `/usr/share/...` and may fail |
| `install_askpass` | Admin-backed | Uses `install_packages` |
| `install_nodejs` | User-space friendly | `nvm` under `$HOME` |

#### Overall verdict for `make system-prereq`

- **Mostly admin-backed**
- Better than before, but still not a safe no-admin target on Linux/WSL2

### `make full-setup`

Definition:

- `makefile:137-143`
- runs:
  1. `make linking-prereq`
  2. `make system-prereq`
  3. `make prereq-layers-all`

#### Phase 1: `make linking-prereq`

| Substep | Status | Notes |
|---|---|---|
| Symlink dotfiles into `$HOME` | User-space friendly | No admin needed |
| Install fonts into user font dirs | User-space friendly | `~/.fonts` / `~/Library/Fonts` |
| Install vim-plug into `~/.vim/...` | User-space friendly | No admin needed |
| Run `vim +PlugInstall` | User-space friendly | Assumes vim exists |

Phase verdict:

- **User-space friendly**

#### Phase 2: `make system-prereq`

Phase verdict:

- **Mostly admin-backed**

See section above.

#### Phase 3: `make prereq-layers-all`

Definition:

- `makefile:9`
- expands to:
  - `shell-layer`
  - `git-layer`
  - `yaml`
  - `markdown`
  - `completion`
  - `vimscript`
  - `latex`
  - `python`
  - `r`
  - `c_cpp`
  - `sql`
  - `js`
  - `html_css`
  - `docker`
  - `kubernetes`
  - `ocaml`
  - `terraform`
  - `rust`
  - `ai-tools`

| Layer target | Status | Notes |
|---|---|---|
| `shell-layer` | Admin-backed | Uses `install_packages` for shell tools |
| `git-layer` | Conditional | Mostly brew-based if brew exists |
| `yaml` | Conditional | npm global install can be user-space if Node came from `nvm` |
| `markdown` | Conditional | Mix of brew/system package install and npm global install |
| `completion` | User-space friendly | Symlink into Emacs snippets dir |
| `vimscript` | Conditional | npm global install; usually user-space with `nvm` |
| `latex` | Conditional | Better on macOS/user-local TeX path; Debian fallback still has privileged/system-package behavior |
| `python` | Admin-backed | Installs system Python/pipx packages via `install_packages` before pipx work |
| `r` | Admin-backed | Uses `install_packages` for R system packages |
| `c_cpp` | Conditional | brew-first if brew exists; fallback package install is admin-backed |
| `sql` | Conditional | brew-first if brew exists; fallback package install is admin-backed |
| `js` | Conditional | brew + npm global; often user-space if brew/nvm already available |
| `html_css` | User-space friendly | Piggybacks on JS layer tooling |
| `docker` | Admin-backed | Fallback installs Docker package; daemon access may also block usage |
| `kubernetes` | Conditional | brew-first if brew exists; fallback package install remains admin-backed |
| `ocaml` | Conditional | brew-first if brew exists; fallback package install is admin-backed, opam itself is user-space |
| `terraform` | Conditional | brew-first on this branch; apt repo fallback is still privileged |
| `rust` | User-space friendly | `rustup` + cargo in user space |
| `ai-tools` | Conditional | Mostly user-space, but npm global behavior depends on nvm/user-local npm setup |

#### Overall verdict for `make prereq-layers-all`

- **Mixed, but still not no-admin-safe overall**
- Several individual layer targets are now workable in user space
- The aggregate target still includes multiple admin-backed layers

### Overall verdict for `make full-setup`

| Phase | Status |
|---|---|
| `linking-prereq` | User-space friendly |
| `system-prereq` | Mostly admin-backed |
| `prereq-layers-all` | Mixed / partially admin-backed |

Final verdict:

- **`make full-setup` is still not suitable as a no-admin WSL2 target**
- The safest near-term no-admin path is closer to:
  - `make spacemacs`
  - plus selected user-space-friendly layer installs
  - with Linuxbrew already present

---

## Suggested future target split

To better support work WSL2 / no-admin machines, consider introducing:

### `make user-setup`

Would include only user-space-safe steps, for example:

- `linking-prereq`
- user-local Emacs build/install
- `node-manual`
- `python-env`
- `rust`
- `completion`
- selected npm/pipx/uv/opam/brew-first targets that can avoid sudo

### `make system-setup`

Would include explicitly privileged steps:

- distro package installation
- `/etc` changes
- apt repo/key setup
- WSL config changes
- anything writing to `/usr/local`

This would make it much clearer how far a user can get on a locked-down machine before asking for admin help.
