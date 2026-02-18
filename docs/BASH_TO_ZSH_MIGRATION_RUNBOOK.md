# Bash → Zsh Migration Runbook (Linux, General)

## Goal
Switch from bash to zsh safely, while keeping intentional customizations and avoiding shell-startup cruft.

## What typically transfers vs what does not

| Category | Auto-restored after reinstall? | Notes |
|---|---|---|
| Tool packages (zsh plugins, CLI tools) | Usually yes | If your setup scripts/package manager install them |
| Repo-managed shell init blocks | Yes | Example: Starship/zoxide/aliases blocks written by setup scripts |
| Language/toolchain PATH additions | Sometimes | Often tied to specific layers (reinstall those layers) |
| Bash-only behavior (`bind`, blesh, bash completion blocks) | No | Replace with zsh-native equivalents |
| Ad-hoc exports/aliases/functions in `~/.bashrc` | No | Manually review and port |
| Host-specific hacks (WSL path cleanup, custom agents) | No | Manual, case-by-case |

## Preflight checks
```bash
echo "$SHELL"
getent passwd "$USER" | cut -d: -f7
command -v zsh
cat /etc/shells
```

## Migration process

1. **Back up shell files**
   ```bash
   cp ~/.bashrc ~/.bashrc.bak.$(date +%Y%m%d%H%M%S)
   [ -f ~/.zshrc ] && cp ~/.zshrc ~/.zshrc.bak.$(date +%Y%m%d%H%M%S)
   ```

2. **Install zsh using your distro package manager**
   - Debian/Ubuntu: `sudo apt install -y zsh`
   - Arch: `sudo pacman -S --needed zsh`
   - Fedora/RHEL: `sudo dnf install -y zsh`
   - openSUSE: `sudo zypper install -y zsh`

3. **Set zsh as login shell**
   ```bash
   chsh -s "$(command -v zsh)"
   ```
   Restart terminal/session completely.

4. **Run your provisioning/setup flow**
   - If using this repo:
     ```zsh
     make cli_tools
     ```
   - If your session still has stale `$SHELL`, force target shell:
     ```bash
     SHELL="$(command -v zsh)" ./prereq_packages.sh install_cli_tools
     ```

5. **Port only intentional customizations**
   Migrate items like:
   - custom PATH exports
   - SSH/keychain/agent setup
   - machine-specific environment variables

   Do **not** copy bash-only editor/bindings into zsh.

6. **De-duplicate startup logic**
   Keep one canonical source for each initializer (e.g., NVM, opam, cargo env), not multiple copies across `.profile`, `.bashrc`, `.zshrc`, `.zshenv`.

7. **Validate**
   ```zsh
   echo "$SHELL"
   echo "$ZSH_VERSION"
   ```
   Confirm prompt, aliases, plugin behavior, and expected PATH entries.

## Rollback
```bash
chsh -s /bin/bash
```
Restart session and restore backup dotfiles if needed.

## Repo-specific note
In this repo, prefer keeping shell wiring centralized in:
- `prereq_packages.sh` (setup logic)
- `.shell_aliases` (shared aliases/functions)
