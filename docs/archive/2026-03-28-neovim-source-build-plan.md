# Neovim source-build experiment plan

## Why explore this

The current Unix `make neovim` path is good enough for general use, but it still
depends on package-manager behavior (Homebrew or distro packages) unless it falls
back to the pinned GitHub release download. A source-build path is worth
exploring when we want:

- a more explicitly known Unix Neovim version
- a repo-owned build story closer to the Emacs source-build flow
- a user-local install prefix that does not depend on admin rights
- tighter control over toolchain and dependency assumptions

## What the official Neovim docs support

- `make CMAKE_BUILD_TYPE=Release` or `RelWithDebInfo`
- `make CMAKE_INSTALL_PREFIX=$HOME/local/nvim install`
- bundled dependencies by default
- optional control over bundled vs system dependencies
- `ninja` and `ccache` support for faster rebuilds

## Repo patterns we can reuse from the Emacs build

- pinned versions in `versions.conf`
- user-local prefixes by default
- Linuxbrew-first dependency strategy with system-package fallback
- dedicated Brewfile for build dependencies
- explicit toolchain verification
- CI/verify mode separated from interactive install mode
- post-build verification before declaring success

## First-pass implementation plan

Use the Spacemacs/Emacs source-build flow as the template:

1. create a dedicated `build_neovim.sh` entrypoint
   - same role as `build_emacs30.sh`
   - source `common_utils.sh` and `versions.conf`
   - default to a user-local prefix
2. use a dedicated dependency bundle
   - `brewfiles/Brewfile.neovim-build`
   - Linuxbrew first, distro fallback second
3. keep the build reproducible
   - pin `NEOVIM_VERSION` in `versions.conf`
   - build the pinned source tarball
   - use bundled Neovim deps by default
4. keep install behavior repo-owned
   - symlink `~/.local/bin/nvim`
   - link repo `nvim/` config
   - preserve the `lazygit` companion behavior
5. make it easy to exercise in CI/local smoke tests
   - `make neovim` is the default Unix source-build path
   - `make neovim-source` remains an explicit alias
   - `ci/neovim-smoke.sh` gets a source-build mode

## First-pass decisions

- make `make neovim` default to source-build on Unix
- keep `make neovim-source` as an explicit alias
- keep package/download install as an explicit fallback only
- build with official `make ...` flow and `CMAKE_EXTRA_FLAGS`
- use bundled Neovim dependencies for reproducibility
- install into `${NEOVIM_PREFIX:-$HOME/.local/neovim}`
- verify the installed binary version before declaring success
- keep the dependency bundle lean: compiler, cmake/ninja, gettext, curl, git, pkg-config, optional ccache

## Proposed shape

### Make source-build the default Unix path

Use the Emacs-style source-build flow as the primary Unix path:

- `make neovim` defaults to source-build
- `make neovim-source` stays as an explicit alias
- package/download install remains available as an explicit fallback only

### Keep an explicit source-build entrypoint

Potential entry points:

- `make neovim`
- `make neovim-source`
- `./prereq_packages.sh install_neovim_source`

Potential defaults:

- `NEOVIM_VERSION` pinned in `versions.conf`
- install prefix: `${NVIM_PREFIX:-$HOME/.local/neovim}`
- build type: `RelWithDebInfo`

Potential dependency bundle:

- `cmake`
- `ninja`
- `gettext`
- `curl`
- `git`
- compiler toolchain (`gcc` / `clang`)
- maybe `ccache`

## Resolved direction

1. The build uses bundled Neovim dependencies for reproducibility.
2. Extra CLI tools like `rg` / `fd` remain the responsibility of `cli_tools_core`.
3. Woodpecker keeps Neovim source-build coverage sequenced after Emacs instead of compiling both at once.

## First-pass outcome

- `build_neovim.sh` now exists as the Emacs-style Neovim source-build entrypoint
- `brewfiles/Brewfile.neovim-build` carries the shared source-build deps
- `make neovim` now defaults to source-build on Unix
- `make neovim-package` remains available as an explicit fallback
- `ci/neovim-smoke.sh` supports source mode and now exercises the default path
- `.woodpecker/build.yml` can run Neovim source-build validation after Emacs,
  instead of compiling both at once
