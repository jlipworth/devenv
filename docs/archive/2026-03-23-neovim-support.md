# Neovim Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add opt-in, cross-platform Neovim + LazyVim support to devenv, with support for Python/JS/TS/YAML/JSON/TOML/Shell/SQL/Markdown plus the branch's additional HTML/CSS, R, LaTeX, Tailwind, conditional PowerShell coverage when `pwsh`/PowerShell is available, optional Harpoon 2 working-set support, and integration into the existing makefile/prereq_packages infrastructure. The keybindings and editor behavior should be traced to current Spacemacs conventions rather than legacy Vim-config assumptions.

**Architecture:** LazyVim distribution bootstrapped via lazy.nvim in `nvim/` directory, symlinked to platform config locations. Mason.nvim auto-installs LSP servers on first launch. `install_neovim()` in `prereq_packages.sh` handles cross-platform binary installation. Windows setup via `setup-dev-tools.ps1`.

**Tech Stack:** Neovim 0.11.6, LazyVim, lazy.nvim, mason.nvim, nvim-lspconfig, Snacks picker/explorer, persistence.nvim, Harpoon 2, nvim-treesitter, which-key.nvim, lazygit

**Spec:** `docs/superpowers/specs/2026-03-23-neovim-support-design.md`

---

### Task 1: Add NEOVIM_VERSION to versions.conf

**Files:**
- Modify: `versions.conf:15` (append after NODE_VERSION)

- [ ] **Step 1: Add version pin**

Add to end of `versions.conf`:

```conf
# Neovim version (used for appimage/zip download when brew unavailable)
NEOVIM_VERSION="0.11.6"
```

- [ ] **Step 2: Verify file**

Run: `cat versions.conf`
Expected: Shows all four version pins (EMACS, GCC, NODE, NEOVIM)

- [ ] **Step 3: Commit**

```bash
git add versions.conf
git commit -m "feat(neovim): pin NEOVIM_VERSION=0.11.6 in versions.conf"
```

---

### Task 2: Create Neovim config — bootstrap files

**Files:**
- Create: `nvim/init.lua`
- Create: `nvim/lua/config/lazy.lua`

- [ ] **Step 1: Create `nvim/init.lua`**

This is the entry point. It bootstraps lazy.nvim (clones it if missing) then loads `config.lazy`:

```lua
-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("config.lazy")
```

- [ ] **Step 2: Create `nvim/lua/config/lazy.lua`**

This calls `require("lazy").setup()` with LazyVim and the local plugins directory:

```lua
require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    { import = "plugins" },
  },
  defaults = { lazy = false },
  checker = { enabled = true },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
```

- [ ] **Step 3: Verify directory structure**

Run: `find nvim/ -type f | sort`
Expected:
```
nvim/init.lua
nvim/lua/config/lazy.lua
```

- [ ] **Step 4: Commit**

```bash
git add nvim/init.lua nvim/lua/config/lazy.lua
git commit -m "feat(neovim): add LazyVim bootstrap (init.lua + config/lazy.lua)"
```

---

### Task 3: Create Neovim config — options and keymaps

**Files:**
- Create: `nvim/lua/config/options.lua`
- Create: `nvim/lua/config/keymaps.lua`

- [ ] **Step 1: Create `nvim/lua/config/options.lua`**

```lua
-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

local opt = vim.opt

-- Match the current `.spacemacs` line-number preference.
opt.number = true
opt.relativenumber = true

-- Match Spacemacs `evil-escape-delay`.
opt.timeoutlen = 200
```

- [ ] **Step 2: Create `nvim/lua/config/keymaps.lua`**

```lua
-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

local map = vim.keymap.set

-- Match current Spacemacs `evil-escape` usage.
map("i", "jk", "<Esc>", { desc = "Exit insert mode" })

-- Approximate `evil-respect-visual-line-mode`: only use screen-line
-- movement when wrapping is enabled for the current buffer.
map({ "n", "x" }, "j", "v:count == 0 && &wrap ? 'gj' : 'j'", { expr = true, silent = true, desc = "Down (respect wrapped lines)" })
map({ "n", "x" }, "k", "v:count == 0 && &wrap ? 'gk' : 'k'", { expr = true, silent = true, desc = "Up (respect wrapped lines)" })
```

- [ ] **Step 3: Verify files exist**

Run: `find nvim/lua/config/ -type f | sort`
Expected:
```
nvim/lua/config/keymaps.lua
nvim/lua/config/lazy.lua
nvim/lua/config/options.lua
```

- [ ] **Step 4: Commit**

```bash
git add nvim/lua/config/options.lua nvim/lua/config/keymaps.lua
git commit -m "feat(neovim): add options and keymaps (jk escape, Spacemacs-compat)"
```

---

### Task 4: Create Neovim config — plugin files

**Files:**
- Create: `nvim/lua/plugins/colorscheme.lua`
- Create: `nvim/lua/plugins/editor.lua`
- Create: `nvim/lua/plugins/lang.lua`

- [ ] **Step 1: Create `nvim/lua/plugins/colorscheme.lua`**

```lua
return {
  -- Use tokyonight as the default colorscheme (LazyVim default, good terminal support)
  {
    "folke/tokyonight.nvim",
    opts = {
      style = "night",
    },
  },

  -- Set it as the LazyVim colorscheme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight-night",
    },
  },
}
```

- [ ] **Step 2: Create `nvim/lua/plugins/editor.lua`**

```lua
return {
  -- Telescope: use ripgrep if available (aligned with current Spacemacs search-tool preferences)
  {
    "nvim-telescope/telescope.nvim",
    opts = {
      defaults = {
        file_ignore_patterns = { ".git/", "node_modules/", "__pycache__/" },
      },
    },
  },
}
```

- [ ] **Step 3: Create `nvim/lua/plugins/lang.lua`**

```lua
return {
  -- LazyVim language extras
  { import = "lazyvim.plugins.extras.lang.python" },
  { import = "lazyvim.plugins.extras.lang.typescript" },
  { import = "lazyvim.plugins.extras.lang.yaml" },
  { import = "lazyvim.plugins.extras.lang.json" },
  { import = "lazyvim.plugins.extras.lang.markdown" },
  { import = "lazyvim.plugins.extras.lang.sql" },
  { import = "lazyvim.plugins.extras.lang.toml" },

  -- Shell LSP (no built-in LazyVim extra — manual config)
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        bashls = {},
      },
    },
  },
  {
    "williamboman/mason.nvim",
    -- Use function form (not table) to merge ensure_installed with entries from
    -- LazyVim language extras, which also contribute to this list.
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "bash-language-server", "shellcheck" })
    end,
  },
}
```

**Note on generated files:** LazyVim auto-generates `lazy-lock.json` (plugin lockfile) and `lazyvim.json` (extras tracker) in the config directory on first launch. Commit `lazy-lock.json` for reproducible builds. Add `lazyvim.json` to `.gitignore` since extras are managed via `import` in `lang.lua`.

- [ ] **Step 4: Create `nvim/.gitignore`**

```gitignore
# LazyVim auto-managed extras tracker (we use import statements instead)
lazyvim.json
```

- [ ] **Step 5: Verify all plugin files**

Run: `find nvim/ -name '*.lua' -o -name '.gitignore' | sort`
Expected:
```
nvim/.gitignore
nvim/lua/plugins/colorscheme.lua
nvim/lua/plugins/editor.lua
nvim/lua/plugins/lang.lua
```

- [ ] **Step 6: Commit**

```bash
git add nvim/lua/plugins/ nvim/.gitignore
git commit -m "feat(neovim): add plugin configs (colorscheme, editor, language extras)"
```

---

### Task 5: Add install_neovim() to prereq_packages.sh

**Files:**
- Modify: `prereq_packages.sh` (add function before `install_all()` at line 1700)
- Modify: `prereq_packages.sh:1730` (add to `valid_functions` array)

- [ ] **Step 1: Add `install_neovim()` function**

Insert before the `install_all()` function (before line 1700):

```bash
install_neovim() {
    log "Installing Neovim and configuring LazyVim..."

    # Source versions.conf for NEOVIM_VERSION
    source "$GNU_DIR/versions.conf"
    local neovim_version="${NEOVIM_VERSION:-0.11.6}"

    # --- Install Neovim binary ---
    if is_installed "nvim"; then
        log "Neovim is already installed: $(nvim --version | head -1)"
    elif is_installed "brew"; then
        log "Installing Neovim via Homebrew..."
        brew install neovim || log "Error installing Neovim via Homebrew." "WARNING"
    elif [[ "$DISTRO" == "arch" ]] && ! no_admin_mode; then
        install_packages "neovim"
    else
        # Fallback: download from GitHub releases (no admin needed)
        log "Installing Neovim v${neovim_version} from GitHub releases..."
        mkdir -p "$HOME/.local/bin"

        local arch
        arch="$(uname -m)"
        case "$arch" in
            x86_64 | amd64) arch="x86_64" ;;
            aarch64 | arm64) arch="aarch64" ;;
            *)
                log "Unsupported architecture $arch for Neovim download." "ERROR"
                return 1
                ;;
        esac

        local nvim_url="https://github.com/neovim/neovim/releases/download/v${neovim_version}/nvim-linux-${arch}.appimage"
        local nvim_dest="$HOME/.local/bin/nvim"

        curl -fsSL "$nvim_url" -o "$nvim_dest" || {
            log "Failed to download Neovim appimage." "ERROR"
            return 1
        }
        chmod +x "$nvim_dest"

        # Test if FUSE is available; if not, extract the appimage
        if ! "$nvim_dest" --version &> /dev/null; then
            log "FUSE not available, extracting appimage..."
            local extract_dir="$HOME/.local/share/nvim-appimage"
            rm -rf "$extract_dir"
            cd /tmp && "$nvim_dest" --appimage-extract > /dev/null 2>&1
            mv /tmp/squashfs-root "$extract_dir"
            rm -f "$nvim_dest"
            ln -sf "$extract_dir/AppRun" "$nvim_dest"
            cd "$GNU_DIR"
        fi

        add_to_path "$HOME/.local/bin" "Neovim"
        log "Neovim installed to $nvim_dest" "SUCCESS"
    fi

    # --- Install lazygit (required for LazyVim git integration) ---
    if ! is_installed "lazygit"; then
        log "Installing lazygit..."
        if is_installed "brew"; then
            brew install lazygit || log "Error installing lazygit via Homebrew." "WARNING"
        elif [[ "$DISTRO" == "arch" ]] && ! no_admin_mode; then
            install_packages "lazygit"
        else
            # Download lazygit binary from GitHub releases
            log "Installing lazygit from GitHub releases..."
            local lg_version
            lg_version=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')

            local lg_arch
            case "$(uname -m)" in
                x86_64 | amd64) lg_arch="x86_64" ;;
                aarch64 | arm64) lg_arch="arm64" ;;
                *) lg_arch="$(uname -m)" ;;
            esac

            local lg_os
            if [[ "$OS" == "Darwin" ]]; then
                lg_os="Darwin"
            else
                lg_os="Linux"
            fi

            curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${lg_version}/lazygit_${lg_version}_${lg_os}_${lg_arch}.tar.gz" \
                -o /tmp/lazygit.tar.gz || {
                log "Failed to download lazygit." "WARNING"
            }

            if [[ -f /tmp/lazygit.tar.gz ]]; then
                tar -xzf /tmp/lazygit.tar.gz -C /tmp lazygit
                mkdir -p "$HOME/.local/bin"
                mv /tmp/lazygit "$HOME/.local/bin/"
                chmod +x "$HOME/.local/bin/lazygit"
                rm /tmp/lazygit.tar.gz
                log "lazygit installed to ~/.local/bin" "SUCCESS"
            fi
        fi
    else
        log "lazygit is already installed."
    fi

    # --- Create Neovim config symlink ---
    local nvim_config_dir="$HOME/.config/nvim"
    local nvim_source="$GNU_DIR/nvim"

    mkdir -p "$HOME/.config"

    if [ -L "$nvim_config_dir" ]; then
        log "A symbolic link already exists at $nvim_config_dir. Replacing it."
        rm "$nvim_config_dir"
    elif [ -d "$nvim_config_dir" ]; then
        log "A directory exists at $nvim_config_dir. Backing it up."
        mv "$nvim_config_dir" "${nvim_config_dir}_backup_$(date +%Y%m%d%H%M%S)"
    fi

    ln -s "$nvim_source" "$nvim_config_dir"
    log "Neovim config symlinked: $nvim_config_dir -> $nvim_source" "SUCCESS"

    log "Neovim setup complete! Run 'nvim' to auto-install plugins and LSP servers on first launch." "SUCCESS"
}
```

- [ ] **Step 2: Add `install_neovim` to `valid_functions` array**

In the `main()` function, add `"install_neovim"` to the `valid_functions` array. Insert after `"install_cli_tools"` (line 1767) and before `"install_all"` (line 1768):

```bash
        "install_neovim"
```

Do NOT add `install_neovim` to the `install_all()` function.

- [ ] **Step 3: Verify function is callable**

Run: `bash -n prereq_packages.sh` (syntax check)
Expected: No output (no syntax errors)

- [ ] **Step 4: Commit**

```bash
git add prereq_packages.sh
git commit -m "feat(neovim): add install_neovim() to prereq_packages.sh

Cross-platform Neovim + lazygit installation:
- Mac/Linux with brew: brew install
- Arch: pacman (respects NO_ADMIN)
- Fallback: appimage + GitHub binary releases
- Creates ~/.config/nvim symlink to repo config"
```

---

### Task 6: Add neovim target to makefile

**Files:**
- Modify: `makefile:3-8` (.PHONY declaration)
- Modify: `makefile` (add target after `ai-tools` target, ~line 164)
- Modify: `makefile:213-227` (help target)

- [ ] **Step 1: Add `neovim` to `.PHONY` declaration**

Append ` neovim` to the end of line 8 (after `help`). The line should end with:

```
        full-setup noadmin-setup help neovim
```

- [ ] **Step 2: Add neovim target**

Insert between the `ai-tools` target (line 163-164) and the `update-deps` target (line 167), with a blank line separator:

```makefile
neovim:
	@echo "Installing Neovim and configuring LazyVim..."
	@./prereq_packages.sh install_neovim
```

- [ ] **Step 3: Add neovim to help target**

In the help target, under "Other targets:" section, add after the last entry (`update-deps` at line 226):

```makefile
	@echo "  neovim          - Install Neovim + LazyVim (opt-in, not part of full-setup)"
```

- [ ] **Step 4: Verify makefile syntax**

Run: `make -n neovim`
Expected: Shows the echo and prereq_packages.sh commands (dry run)

Run: `make help | grep neovim`
Expected: Shows the neovim help line

- [ ] **Step 5: Verify full-setup is unchanged**

Run: `make -n full-setup`
Expected: Does NOT contain `neovim` or `install_neovim`

- [ ] **Step 6: Commit**

```bash
git add makefile
git commit -m "feat(neovim): add opt-in 'make neovim' target

Standalone target, not part of full-setup or prereq-layers-all."
```

---

### Task 7: Update setup-dev-tools.ps1 with Neovim + repo clone

**Files:**
- Copy into repo: `setup-dev-tools.ps1` (currently at `~/setup-dev-tools.ps1`, needs to be in `$GNU_DIR/`)
- Modify: `setup-dev-tools.ps1`

- [ ] **Step 0: Copy the file into the repo**

```bash
cp ~/setup-dev-tools.ps1 ~/GNU_files/setup-dev-tools.ps1
```

- [ ] **Step 1: Update the script**

The script currently has 4 steps. We are adding 3 more (clone devenv, install Neovim, link config) for a total of 7. Update:
- All existing `[1/4]`→`[1/7]`, `[2/4]`→`[2/7]`, `[3/4]`→`[3/7]`, `[4/4]`→`[4/7]`
- Add 3 new sections after the uv section
- Update the summary block at the end to include all 7 tools

Add after the uv section:

```powershell
# --- 5. Clone devenv repo ---
Write-Host "`n[5/7] Cloning devenv repo..." -ForegroundColor Yellow

$devenvPath = "$env:USERPROFILE\GNU_files"
if (-not (Test-Path "$devenvPath\.git")) {
    git clone https://github.com/jlipworth/devenv.git $devenvPath
    Write-Host "devenv cloned to $devenvPath" -ForegroundColor Green
} else {
    git -C $devenvPath pull --ff-only
    Write-Host "devenv updated at $devenvPath" -ForegroundColor Green
}

# --- 6. Neovim ---
Write-Host "`n[6/7] Installing Neovim..." -ForegroundColor Yellow

if (-not (Get-Command nvim -ErrorAction SilentlyContinue)) {
    # Try winget first
    $wingetSuccess = $false
    try {
        winget install Neovim.Neovim --scope user --accept-source-agreements --accept-package-agreements
        $wingetSuccess = $true
    } catch {
        Write-Host "winget install failed, falling back to portable zip..." -ForegroundColor Yellow
    }

    if (-not $wingetSuccess) {
        # Fallback: download portable zip
        $nvimDir = "$env:LOCALAPPDATA\nvim-bin"
        $nvimZip = "$env:TEMP\nvim-win64.zip"
        # Version pinned here — keep in sync with versions.conf NEOVIM_VERSION
        Invoke-WebRequest -Uri "https://github.com/neovim/neovim/releases/download/v0.11.6/nvim-win64.zip" -OutFile $nvimZip
        Expand-Archive -Path $nvimZip -DestinationPath $nvimDir -Force
        Remove-Item $nvimZip
        # Add to session and user PATH
        $nvimBinPath = "$nvimDir\nvim-win64\bin"
        if ($env:Path -notlike "*$nvimBinPath*") {
            $env:Path += ";$nvimBinPath"
        }
        [Environment]::SetEnvironmentVariable("Path", "$([Environment]::GetEnvironmentVariable('Path', 'User'));$nvimBinPath", "User")
    }
}

Write-Host "Neovim: $(nvim --version | Select-Object -First 1)" -ForegroundColor Green

# --- 7. Neovim config junction ---
Write-Host "`n[7/7] Linking Neovim config..." -ForegroundColor Yellow

$nvimConfigPath = "$env:LOCALAPPDATA\nvim"
$nvimSourcePath = "$devenvPath\nvim"

if (Test-Path $nvimConfigPath) {
    if ((Get-Item $nvimConfigPath).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        Remove-Item $nvimConfigPath -Force
    } else {
        $backupPath = "${nvimConfigPath}_backup_$(Get-Date -Format 'yyyyMMddHHmmss')"
        Move-Item $nvimConfigPath $backupPath
        Write-Host "Existing nvim config backed up to $backupPath" -ForegroundColor Yellow
    }
}

try {
    New-Item -ItemType Junction -Path $nvimConfigPath -Target $nvimSourcePath -ErrorAction Stop | Out-Null
    Write-Host "Neovim config linked: $nvimConfigPath -> $nvimSourcePath" -ForegroundColor Green
} catch {
    # Junction fails on network shares — fall back to copy
    Write-Host "Junction failed (network share?), copying config instead..." -ForegroundColor Yellow
    Copy-Item -Path $nvimSourcePath -Destination $nvimConfigPath -Recurse
    Write-Host "Neovim config copied to $nvimConfigPath (manual sync needed after repo updates)" -ForegroundColor Yellow
}
```

Also update the summary block at the end of the script to include all tools:

```powershell
# --- Done ---
Write-Host "`n=== All tools installed ===" -ForegroundColor Cyan
Write-Host "  git   : $(git --version)"
Write-Host "  node  : $(node --version)"
Write-Host "  npm   : $(npm --version)"
Write-Host "  codex : $codexVersion"
Write-Host "  uv    : $(uv --version)"
Write-Host "  nvim  : $(nvim --version | Select-Object -First 1)"
Write-Host "  devenv: $devenvPath"
```

- [ ] **Step 2: Verify PowerShell syntax**

Run: `pwsh -Command "Get-Content setup-dev-tools.ps1 | Select-Object -First 5"` (if pwsh available) or just visually inspect.

- [ ] **Step 3: Commit**

```bash
git add setup-dev-tools.ps1
git commit -m "feat(neovim): add Neovim + devenv clone to Windows setup script

Moves setup-dev-tools.ps1 into repo.
Installs Neovim via winget (fallback: portable zip).
Clones devenv repo and creates config junction (fallback: copy for network shares)."
```

---

### Task 8: Create keybinding reference doc

**Files:**
- Create: `docs/NEOVIM_KEYBINDINGS.md`

- [ ] **Step 1: Create the reference card**

```markdown
# Neovim (LazyVim) Keybinding Reference

Quick reference for Spacemacs users transitioning to Neovim with LazyVim.
Leader key is Space (same as Spacemacs).

## Core Navigation

| Action | Spacemacs | LazyVim | Notes |
|--------|-----------|---------|-------|
| Escape | `jk` | `jk` | Custom (config/keymaps.lua) |
| Find file | `SPC f f` | `<leader>ff` | Snacks picker |
| Recent files | `SPC f r` | `<leader>fr` | Snacks picker |
| Grep project | `SPC /` | `<leader>sg` | Snacks live grep |
| File explorer | `SPC f t` | `<leader>e` | Snacks explorer |
| Buffer list | `SPC b b` | `<leader>fb` | Snacks buffers |
| Switch buffer | `SPC b n/p` | `[b` / `]b` | Previous/next buffer |
| Close buffer | `SPC b d` | `<leader>bd` | |
| Save file | `SPC f s` | `<leader>w` or `:w` | |
| Command history | `SPC SPC` | `<leader>:` | Commands live at `<leader>sC` |

## Windows and Splits

| Action | Spacemacs | LazyVim | Notes |
|--------|-----------|---------|-------|
| Split vertical | `SPC w v` | `<leader>wv` or `<C-w>v` | |
| Split horizontal | `SPC w s` | `<leader>ws` or `<C-w>s` | |
| Close window | `SPC w d` | `<leader>wd` or `<C-w>c` | |
| Switch window | `SPC w w` | `<C-w>w` | |
| Move to window | `SPC w h/j/k/l` | `<C-h/j/k/l>` | LazyVim default |

## Git

| Action | Spacemacs | LazyVim | Notes |
|--------|-----------|---------|-------|
| Git status | `SPC g s` | `<leader>gg` | Opens lazygit |
| Git blame | `SPC g b` | `<leader>gb` | Inline blame |
| Git diff | `SPC g d` | `<leader>gd` | Diffview |
| Next hunk | `] h` | `]h` | |
| Prev hunk | `[ h` | `[h` | |

## LSP

| Action | Spacemacs | LazyVim | Notes |
|--------|-----------|---------|-------|
| Go to definition | `g d` | `gd` | Same |
| Go to references | `g r` | `gr` | Same |
| Hover docs | `K` | `K` | Same |
| Rename symbol | `SPC l r` | `<leader>cr` | |
| Code action | `SPC l a` | `<leader>ca` | |
| Format buffer | `SPC l =` | `<leader>cf` | |
| Diagnostics list | `SPC l e` | `<leader>xx` | Trouble |
| Next diagnostic | `] d` | `]d` | |
| Prev diagnostic | `[ d` | `[d` | |
| LSP info | | `:LspInfo` | Check attached servers |

## Search and Replace

| Action | Spacemacs | LazyVim | Notes |
|--------|-----------|---------|-------|
| Search in buffer | `/` | `/` | Same |
| Search word under cursor | `*` | `*` | Same |
| Search and replace | `:%s/old/new/g` | `:%s/old/new/g` | Same (standard Ex workflow) |
| Clear search highlight | `SPC s c` | `<Esc>` | LazyVim clears on Esc |

## Which-Key

Press `<leader>` (Space) and wait — which-key shows all available bindings grouped by category. This works the same way as Spacemacs's SPC menu.

Key groups:
- `<leader>f` — File/Find
- `<leader>g` — Git
- `<leader>b` — Buffers
- `<leader>c` — Code (LSP)
- `<leader>s` — Search
- `<leader>w` — Windows
- `<leader>x` — Diagnostics/Trouble
- `<leader>u` — UI toggles

## Custom Additions

| Action | Keybinding | Notes |
|--------|-----------|-------|
| Insert date | `<localleader>oc` | Inserts "Mon DD, YYYY" in `tex`/`org` buffers, matching the current Spacemacs major-mode date habit |

## Sessions / Workspace Story

Neovim does not have Spacemacs layout parity out of the box. The practical workflow here is:

- `<leader>fp` for project switching
- `persistence.nvim` for saved sessions (`<leader>qs`, `<leader>ql`, `<leader>qS`, `<leader>qd`)
- Harpoon 2 for an optional per-project working set (`<leader>ha`, `<leader>hh`, `<leader>h1` ... `<leader>h4`)
- tmux as an extra option on Unix/WSL/remote setups, not a baseline requirement

## Windows / PowerShell Note

- `.ps1` / windows-scripts support is provided through `powershell_es` when `pwsh` or `powershell` is available on PATH.
- Mason installs `powershell-editor-services` only when a PowerShell executable is detected, avoiding failed installs on machines without PowerShell.
- This is intended to cover the practical Neovim equivalent of `windows-scripts`, not full Spacemacs parity.

## Harpoon 2 Note

- Installed from `ThePrimeagen/harpoon` on the `harpoon2` branch.
- It is optional and safe to ignore if picker + buffers + sessions are enough for you.
- Initial config only covers file marks / working-set navigation; terminal/command workflows can be added later if they prove useful.

## Tips for Spacemacs Users

1. **Leader is the same** — Space key works identically as the leader
2. **Evil mode is not a separate plugin here** — LazyVim keeps the modal editing model familiar for Spacemacs Evil users. Motions like `hjkl`, `ciw`, and `dd` still feel the same.
3. **Which-key is your friend** — press Space and read the popup, just like Spacemacs
4. **`:` commands still work** — `:w`, `:q`, `:wq`, `:%s` are available through the usual Ex command line
5. **Snacks picker/explorer replace the older Telescope/Neo-tree assumption** in earlier drafts
6. **Mason manages LSPs** — run `:Mason` to see/install/update language servers
7. **Lazy manages plugins** — run `:Lazy` to see/update/install plugins
```

- [ ] **Step 2: Commit**

```bash
git add docs/NEOVIM_KEYBINDINGS.md
git commit -m "docs: add Neovim keybinding reference for Spacemacs users"
```

---

### Task 9: Verify no existing targets are modified

**Files:**
- Read-only verification of: `makefile`, `prereq_packages.sh`

- [ ] **Step 1: Verify full-setup does not include neovim**

Run: `make -n full-setup 2>&1 | grep -i neovim`
Expected: No output (neovim is not part of full-setup)

- [ ] **Step 2: Verify noadmin-setup does not include neovim**

Run: `make -n noadmin-setup 2>&1 | grep -i neovim`
Expected: No output

- [ ] **Step 3: Verify prereq-layers-all does not include neovim**

Run: `make -n prereq-layers-all 2>&1 | grep -i neovim`
Expected: No output

- [ ] **Step 4: Verify install_all() does not call install_neovim**

Run: `grep -A 30 '^install_all()' prereq_packages.sh | grep neovim`
Expected: No output

- [ ] **Step 5: Verify neovim target works standalone**

Run: `make -n neovim`
Expected: Shows echo and prereq_packages.sh commands

- [ ] **Step 6: Verify legacy Vim config is unchanged**

Run: `git diff` against the legacy Vim config
Expected: No output (no changes)

- [ ] **Step 7: Verify .spacemacs is unchanged**

Run: `git diff .spacemacs`
Expected: No output (no changes)

---

### Task 10: Integration test on Linux

- [ ] **Step 1: Run `make neovim` (if Neovim not already installed)**

Run: `make neovim`
Expected: Installs Neovim + lazygit, creates config symlink

- [ ] **Step 2: Verify config symlink**

Run: `ls -la ~/.config/nvim`
Expected: Symlink pointing to `$HOME/GNU_files/nvim`

- [ ] **Step 3: Launch Neovim and let plugins install**

Run: `nvim --headless "+Lazy! sync" +qa`
Expected: Plugins download and install (may take 1-2 minutes)

- [ ] **Step 4: Verify LSP servers install via Mason**

Run: `nvim --headless "+MasonInstall pyright typescript-language-server yaml-language-server json-lsp bash-language-server" +qa`
Expected: LSP servers install to `~/.local/share/nvim/mason/`

- [ ] **Step 5: Verify no regressions**

Run: `make -n full-setup 2>&1 | grep -i neovim`
Expected: No output

- [ ] **Step 6: Final commit (if any fixups needed)**

```bash
git add -A
git commit -m "fix(neovim): integration test fixups"
```
