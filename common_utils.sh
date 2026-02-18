#!/bin/bash

# Detect OS
OS="$(uname -s)"

# Standard directory paths
# In CI, use current working directory (repo is cloned to /workspace)
# Otherwise, use the standard $HOME/GNU_files location
if [[ "$CI" == "true" ]]; then
    GNU_DIR="$(pwd)"
else
    GNU_DIR="$HOME/GNU_files"
fi

# =============================================================================
# Logging function (must be defined first - used throughout)
# =============================================================================
log() {
    local message="$1"       # First argument is the message
    local level="${2:-INFO}" # Second argument is the log level (defaults to INFO)

    case "$level" in
        INFO)
            echo -e "\033[1;34m[INFO]\033[0m $message" # Blue
            ;;
        SUCCESS)
            echo -e "\033[1;32m[SUCCESS]\033[0m $message" # Green
            ;;
        WARNING)
            echo -e "\033[1;33m[WARNING]\033[0m $message" # Yellow
            ;;
        ERROR)
            echo -e "\033[1;31m[ERROR]\033[0m $message" # Red
            ;;
        DEBUG)
            echo -e "\033[1;35m[DEBUG]\033[0m $message" # Purple
            ;;
        *)
            echo -e "\033[1;34m[INFO]\033[0m $message" # Default format goes to INFO
            ;;
    esac
}

# =============================================================================
# Package manager configuration
# =============================================================================
if [[ "$OS" == "Darwin" ]]; then
    DISTRO="macos"
    INSTALL_CMD="brew install"
    CASK_CMD="brew install --cask"
    PIP_CMD="pipx install --include-deps"
    NODE_CMD="npm"
    UPDATE_CMD="brew update"
    CHECK_UPGRADE_CMD="brew outdated"
    UPGRADE_CMD="brew upgrade"
elif grep -qi 'arch\|endeavour\|manjaro' /etc/os-release 2> /dev/null; then
    DISTRO="arch"
    INSTALL_CMD="sudo pacman -S --needed --noconfirm"
    BREW_MANUAL_CMD="brew install"
    CASK_CMD="$INSTALL_CMD" # Placeholder, since Linux doesn't use cask
    PIP_CMD="pipx install --include-deps"
    NODE_CMD="npm"
    # Intentionally avoid metadata-only sync in helper flows.
    # Full system upgrades should be explicit (safe-update or pacman -Syu).
    UPDATE_CMD="true"
    CHECK_UPGRADE_CMD="pacman -Qu"
    UPGRADE_CMD="sudo pacman -S --noconfirm"
    # AUR helper detection
    if command -v yay &> /dev/null; then
        AUR_CMD="yay -S --needed --noconfirm"
    elif command -v paru &> /dev/null; then
        AUR_CMD="paru -S --needed --noconfirm"
    else
        AUR_CMD=""
    fi
elif grep -qi 'debian\|ubuntu\|mint' /etc/os-release 2> /dev/null; then
    DISTRO="debian"
    INSTALL_CMD="sudo apt install -y"
    BREW_MANUAL_CMD="brew install"
    CASK_CMD="$INSTALL_CMD" # Placeholder, since Linux doesn't use cask
    PIP_CMD="pipx install --include-deps"
    NODE_CMD="npm"
    UPDATE_CMD="sudo apt update -qq"
    CHECK_UPGRADE_CMD="apt list --upgradable 2>/dev/null | grep"
    UPGRADE_CMD="sudo apt install --only-upgrade -y"
elif grep -qi 'fedora\|rhel\|centos' /etc/os-release 2> /dev/null; then
    DISTRO="fedora"
    log "Fedora-based. Not tested. Use at your own risk." "WARNING"
    INSTALL_CMD="sudo dnf install -y"
    BREW_MANUAL_CMD="brew install"
    CASK_CMD="$INSTALL_CMD" # Placeholder for Fedora
    PIP_CMD="pipx install --include-deps"
    NODE_CMD="npm"
    UPDATE_CMD="sudo dnf makecache -q"
    CHECK_UPGRADE_CMD="dnf check-update >/dev/null 2>&1 && echo update_available"
    UPGRADE_CMD="sudo dnf upgrade -y"
else
    DISTRO="unknown"
    log "Unsupported OS: $OS"
    log "Only OS's that are fully supported are MacOS, Arch-based, and Debian-based distros."
    exit 1
fi

# =============================================================================
# CI-specific configuration (avoid sudo, ensure PATH includes user dirs)
# =============================================================================
if [[ "$CI" == "true" ]]; then
    # npm: use user-local prefix instead of /usr/lib/node_modules
    NPM_GLOBAL_DIR="$HOME/.npm-global"
    mkdir -p "$NPM_GLOBAL_DIR"
    npm config set prefix "$NPM_GLOBAL_DIR"

    # Add user bin directories to PATH (npm, pipx, go, etc.)
    export PATH="$HOME/.local/bin:$NPM_GLOBAL_DIR/bin:$HOME/go/bin:$PATH"
fi

# Check if a dependency is installed.
# Historically this checked only PATH, but many callers pass package names that
# don't correspond 1:1 with a binary (e.g. "pulseaudio-utils", "gnupg").
is_installed() {
    local name="$1"

    # 1) Fast path: command exists in PATH.
    if command -v "$name" &> /dev/null; then
        log "$name is detected in PATH."
        return 0
    fi

    # 2) Package-manager-backed checks for package-name dependencies.
    # Use brew when present (macOS Homebrew and Linuxbrew).
    if command -v brew &> /dev/null; then
        if brew list --versions "$name" &> /dev/null; then
            log "$name is installed via Homebrew."
            return 0
        fi
    fi

    if [[ "$DISTRO" == "debian" ]] && command -v dpkg &> /dev/null; then
        if dpkg -s "$name" &> /dev/null; then
            log "$name package is installed (dpkg)."
            return 0
        fi
    elif [[ "$DISTRO" == "arch" ]] && command -v pacman &> /dev/null; then
        if pacman -Qi "$name" &> /dev/null; then
            log "$name package is installed (pacman)."
            return 0
        fi
    fi

    log "$name is not installed (not in PATH and no matching package found)."
    return 1
}

# =============================================================================
# Shell configuration helpers
# =============================================================================

# Get the current shell's RC file path
get_shell_rc() {
    case "$SHELL" in
        */zsh) echo "$HOME/.zshrc" ;;
        */bash) echo "$HOME/.bashrc" ;;
        *) echo "$HOME/.bashrc" ;;
    esac
}

# Get the current shell name (for tools like zoxide that need it)
get_shell_name() {
    case "$SHELL" in
        */zsh) echo "zsh" ;;
        */bash) echo "bash" ;;
        *) echo "bash" ;;
    esac
}

# Add a directory to PATH in shell RC file (idempotent)
# Usage: add_to_path "/path/to/dir" "Comment for the export"
add_to_path() {
    local dir="$1"
    local comment="${2:-Added by devenv}"
    local shell_rc
    shell_rc="$(get_shell_rc)"

    if ! grep -q "$dir" "$shell_rc" 2> /dev/null; then
        log "Adding $dir to PATH in $shell_rc..."
        {
            echo ""
            echo "# $comment"
            echo "export PATH=\"$dir:\$PATH\""
        } >> "$shell_rc"
        log "Added $dir to PATH." "SUCCESS"
    else
        log "$dir already in PATH."
    fi
}

# Add a line to shell RC file if not present (idempotent)
# Usage: add_to_shell_rc "eval \"\$(opam env)\"" "opam configuration"
add_to_shell_rc() {
    local line="$1"
    local comment="${2:-Added by devenv}"
    local shell_rc
    shell_rc="$(get_shell_rc)"

    if ! grep -qF "$line" "$shell_rc" 2> /dev/null; then
        log "Adding to $shell_rc: $line"
        {
            echo ""
            echo "# $comment"
            echo "$line"
        } >> "$shell_rc"
        log "Configuration added to $shell_rc." "SUCCESS"
    else
        log "Configuration already present in $shell_rc."
    fi
}

# General function to install multiple packages
install_packages() {
    local updated=false

    # Run update once, only if needed
    if [[ "$updated" == "false" ]]; then
        if [[ "$DISTRO" == "arch" ]]; then
            log "Skipping metadata-only refresh on Arch (avoid partial-upgrade state)"
        else
            log "Checking for new repositories..."
            $UPDATE_CMD
        fi
        updated=true
    fi
    for package in "$@"; do
        if ! is_installed "$package"; then
            log "$package not found. Installing..."
            $INSTALL_CMD "$package" || echo "Error installing $package."
        else
            log "$package is already installed. Checking for updates..."

            # Check if the package needs an update (without unsafe eval)
            if [[ "$DISTRO" == "debian" ]]; then
                # Check apt upgradable list for this package
                if apt list --upgradable 2> /dev/null | grep -q "^${package}/"; then
                    log "$package has an update available. Updating..."
                    sudo apt install --only-upgrade -y "$package" || echo "Error updating $package."
                else
                    log "$package is up-to-date."
                fi
            elif [[ "$DISTRO" == "arch" ]]; then
                # Avoid per-package upgrades on Arch to prevent partial-upgrade conflicts.
                # Run a full upgrade separately (safe-update or pacman -Syu).
                if pacman -Qu "$package" 2> /dev/null | grep -q "^${package}"; then
                    log "$package has an update available."
                    log "Skipping per-package upgrade on Arch; run full system upgrade (safe-update or sudo pacman -Syu)." "WARNING"
                else
                    log "$package is up-to-date."
                fi
            elif [[ "$OS" == "Darwin" ]]; then
                # Check if package is in brew outdated list
                if brew outdated 2> /dev/null | grep -q "^${package}$"; then
                    log "$package has an update available. Updating..."
                    brew upgrade "$package" || echo "Error updating $package."
                else
                    log "$package is up-to-date."
                fi
            else
                log "$package is up-to-date."
            fi

        fi
    done
}

# Install AUR packages (Arch only)
install_aur_packages() {
    if [[ "$DISTRO" != "arch" ]]; then
        log "AUR packages only available on Arch-based systems." "WARNING"
        return 0
    fi

    if [[ -z "$AUR_CMD" ]]; then
        log "No AUR helper found (yay or paru). Skipping AUR packages." "WARNING"
        return 1
    fi

    for package in "$@"; do
        if ! is_installed "$package"; then
            log "$package not found. Installing from AUR..."
            $AUR_CMD "$package" || echo "Error installing AUR package $package."
        else
            log "$package is already installed."
        fi
    done
}
