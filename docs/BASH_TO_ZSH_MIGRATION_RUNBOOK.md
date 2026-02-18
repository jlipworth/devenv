# Bash → Zsh Migration Runbook

Prototype machine baseline (captured on **2026-02-18**):
- OS: Ubuntu 24.04.3 LTS (WSL2)
- Current login shell: `/bin/bash`
- `zsh` present via Homebrew at `/home/linuxbrew/.linuxbrew/bin/zsh`
- `/etc/shells` does **not** currently include a zsh path

## Goal
Switch a machine from bash to zsh without losing useful customizations, while keeping repo-managed CLI tooling behavior (`make cli_tools`, `.shell_aliases`, Starship, zoxide, syntax plugins).

## Preflight
```bash
echo "$SHELL"
getent passwd "$USER" | cut -d: -f7
command -v zsh
bat /etc/shells
```

## Prototype `.bashrc` triage (what to migrate vs drop)

### Reinstall behavior (important)

If you only run `make cli_tools`, shell plumbing is restored (Starship, zoxide, `.shell_aliases`, zsh plugins), but language-layer PATH setup is not.

| Item from prototype `.bashrc` | Restored automatically? | How |
|---|---|---|
| `eval "$(starship init ...)"` | Yes | `make cli_tools` / `install_cli_tools` |
| `eval "$(zoxide init ...)"` | Yes | `make cli_tools` / `install_cli_tools` |
| `source ~/.shell_aliases` | Yes | `make cli_tools` / `install_cli_tools` |
| LLVM path (`.../opt/llvm/bin`) | Yes (layer) | `make c_cpp` |
| Go bin path (`~/go/bin`) | Yes (layer) | `make sql` |
| `brew shellenv` | Maybe/partial | Homebrew path is added by installer; explicit shellenv line is not guaranteed |
| WSL PATH cleanup (`/mnt/c/Program Files*`) | No | Manual unless you adopt `setup_wsl_config` flow |
| keychain SSH block | No | Manual |
| `PATH+=~/.claude/local` | Not guaranteed | External installer behavior, not explicitly managed here |
| `BUN_INSTALL` + `~/.bun/bin` | Usually no | Bun is installed via Homebrew in this repo |
| `ulimit -c unlimited` | No | Manual |

### Keep / migrate (if still desired)
- Homebrew init (`brew shellenv`)
- WSL PATH cleanup (remove `/mnt/c/Program Files*` entries)
- Keychain SSH block
- `PATH` additions for:
  - `~/.claude/local`
  - `~/.bun/bin` (+ `BUN_INSTALL`)
  - Homebrew LLVM (`.../opt/llvm/bin`)
  - `~/go/bin`
- `ulimit -c unlimited` (if intentionally needed)

### Let repo manage in zsh (do not hand-copy from bash)
- `eval "$(zoxide init bash)"` → repo writes `... init zsh`
- `eval "$(starship init bash)"` → repo writes `... init zsh`
- `source ~/.shell_aliases` block (repo keeps this at end)
- Bash vi-mode binds (`set -o vi`, `bind ...`)  
  zsh vi behavior is handled by `zsh-vi-mode` in `.shell_aliases`
- blesh/Bash-specific behavior

### Likely cruft / duplicates to clean
- Manual NVM init block in `.bashrc` duplicates NVM loading already in `.shell_aliases`
- OPAM appears twice (`init.sh` + `eval "$(opam env)"`) — keep one approach
- Cargo is sourced in multiple places (`~/.profile`, `~/.bashrc`, `~/.zshenv`) — keep one canonical source

## Migration steps

1. **Backup shell dotfiles**
   ```bash
   cp ~/.bashrc ~/.bashrc.bak.$(date +%Y%m%d%H%M%S)
   [ -f ~/.zshrc ] && cp ~/.zshrc ~/.zshrc.bak.$(date +%Y%m%d%H%M%S)
   ```

2. **Install distro zsh (recommended for `chsh`)**
   ```bash
   sudo apt update && sudo apt install -y zsh
   command -v zsh
   bat /etc/shells
   ```

3. **Switch login shell**
   ```bash
   chsh -s /usr/bin/zsh
   ```
   Then fully restart terminal/WSL session.

4. **Run repo provisioning from zsh**
   ```zsh
   make cli_tools
   ```
   This should populate `~/.zshrc` with zoxide/starship init and `.shell_aliases` sourcing.

   If you are still in an old bash-launched session and `$SHELL` is stale, force target shell explicitly:
   ```bash
   SHELL=/usr/bin/zsh ./prereq_packages.sh install_cli_tools
   ```

5. **Port selected customizations**
   Add only the “Keep / migrate” items to `~/.zshrc` (place them **before** the final `.shell_aliases` source block).

6. **Validation**
   ```zsh
   echo "$SHELL"
   echo "$ZSH_VERSION"
   rg -n "starship init|zoxide init|shell_aliases" ~/.zshrc
   ```
   Sanity checks:
   - prompt loads (Starship)
   - `z foo` works (zoxide)
   - aliases (`ls`, `cat`, `fd`, `rg`) resolve from `.shell_aliases`

## Rollback
```bash
chsh -s /bin/bash
```
Restart session and restore backups if needed.

## Notes for future machine migrations
- Prefer distro zsh path (`/usr/bin/zsh`) for login shell stability.
- Keep repo-managed shell wiring centralized in `prereq_packages.sh` + `.shell_aliases`.
- Avoid duplicating init blocks across `.profile`, `.bashrc`, `.zshrc`, `.zshenv`.
