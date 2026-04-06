---
name: repo-conventions
description: "Use when editing shell scripts, makefiles, or brewfiles in this repo, or when adding a new language layer. Covers OS detection, idempotency, package installation, shell RC manipulation, and the full new-layer checklist."
---

# GNU_files Repo Conventions

## Editing Existing Scripts

### OS Detection and Package Managers

Never hardcode `apt`, `brew`, or `pacman`. Use the abstractions from `common_utils.sh`:

- `$OS` — `"Darwin"` or `"Linux"`
- `$DISTRO` — `"macos"`, `"arch"`, `"debian"`, `"fedora"`
- `$INSTALL_CMD` — resolved package install command (e.g., `sudo pacman -S --needed --noconfirm`)
- `$CASK_CMD` — macOS cask installs
- `$PIP_CMD` — `pipx install --include-deps`
- `$NODE_CMD` — `npm`

### Idempotency

Always check before installing:
```bash
if ! is_installed "tool-name"; then
    $INSTALL_CMD tool-name
fi
```

`is_installed()` checks PATH first, then falls back to package manager queries.

### Shell RC Manipulation

Never append to `.bashrc` or `.zshrc` directly. Use these functions from `common_utils.sh`:

- `add_to_shell_rc "line"` — appends a single line (idempotent, checks for duplicates)
- `add_to_shell_rc_block "MARKER" "content"` — adds a guarded block with begin/end markers
- `add_to_path "/some/path"` — adds to PATH in shell RC

**Critical ordering:** `.shell_aliases` must be sourced LAST in the RC file because it contains `ble-attach` at the bottom. The `install_cli_tools()` function handles this.

### Logging

Use the `log` function, never raw `echo`:
```bash
log "Installing foo..." "INFO"
log "foo installed successfully" "SUCCESS"
log "foo not available, skipping" "WARNING"
log "foo installation failed" "ERROR"
```

### NO_ADMIN Path

All system package installs must respect `$NO_ADMIN`. When `NO_ADMIN=true`, skip `sudo` package managers and fall back to Homebrew/Linuxbrew or user-local installs:
```bash
if [[ "$NO_ADMIN" == "true" ]]; then
    brew install tool-name
else
    $INSTALL_CMD tool-name
fi
```

### Arch Package Translation

When adding Debian package names, add a mapping in `translate_arch_pkg()` at the top of `prereq_packages.sh` if the Arch name differs. Use `install_packages_translated` to install with auto-translation.

### Function Naming

Installation functions in `prereq_packages.sh` use one of: `install_<layer>_prereqs()`, `install_<layer>_support()`, or `install_<layer>_tools()`.

### Version Pinning

Versions live in `versions.conf` and are sourced by build scripts. Never hardcode version numbers in scripts.

## New Layer Checklist

When adding a new language layer, complete all of these steps:

1. **Add install function** in `prereq_packages.sh`:
   ```bash
   install_<layer>_prereqs() {
       log "Installing <layer> prerequisites..."
       if ! is_installed "<tool>"; then
           $INSTALL_CMD <package>
       fi
       # npm/pip tools:
       if ! is_installed "<npm-tool>"; then
           $NODE_CMD install -g <npm-tool>
       fi
       log "<layer> prerequisites installed." "SUCCESS"
   }
   ```

2. **Add make target** in `makefile`:
   ```makefile
   <layer>:
   	@echo "Installing <Layer> tools..."
   	@./prereq_packages.sh install_<layer>_prereqs
   ```
   Add the target name to the `.PHONY` list at the top.

3. **Create Brewfile** (if macOS/Homebrew packages are needed):
   ```
   # brewfiles/Brewfile.<layer>
   # <Layer> layer
   # Install: brew bundle --file=brewfiles/Brewfile.<layer>

   brew "<package>"
   ```

4. **Add CI job** in `.woodpecker/layers.yml`:
   ```yaml
   - name: layer-<layer>
     image: *ci_image
     depends_on: []
     environment:
       CI: "true"
       DEBIAN_FRONTEND: noninteractive
     commands:
       - make <layer>
   ```

5. **Add to `prereq-layers-all`** in `makefile` if it should run during `make full-setup`.

6. **Validate:**
   ```bash
   pre-commit run --all-files
   ```
