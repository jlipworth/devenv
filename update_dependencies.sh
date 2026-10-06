#!/bin/bash
# Update all dependencies after merging Renovate MRs
# Run this after pulling/merging dependency updates from git

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=common_utils.sh
source "$SCRIPT_DIR/common_utils.sh"
set -e

log "Starting dependency update process..." "INFO"

# Change to repository directory (GNU_DIR is set by common_utils.sh)
REPO_DIR="$GNU_DIR"
cd "$REPO_DIR" || {
    log "Failed to change to $REPO_DIR" "ERROR"
    exit 1
}

# Pull latest changes
log "Pulling latest changes from git..."
git pull origin main || git pull origin master || {
    log "Failed to pull from git. Are you on the right branch?" "ERROR"
    exit 1
}

# npm packages are always installed at latest version (language servers)
# No version tracking needed - they're installed fresh via prereq_packages.sh
log "npm packages: Run 'make js' or 'make yaml' etc. to reinstall at latest." "INFO"

# Update Python packages, using the same tool install_python_prereqs used:
# uv on NO_ADMIN Linux, pipx everywhere else.
if [[ -f "requirements.txt" ]]; then
    log "Updating Python packages..."
    py_tool=""
    if [[ "$OS" == "Linux" ]] && no_admin_mode; then
        command -v uv &> /dev/null && py_tool="uv"
    elif command -v pipx &> /dev/null; then
        py_tool="pipx"
    fi

    if [[ -n "$py_tool" ]]; then
        while IFS= read -r package || [ -n "$package" ]; do
            # Skip empty lines and comments
            [[ -z "$package" || "$package" =~ ^# ]] && continue

            package_spec=$(echo "$package" | xargs)

            # Extract package name (before [extras] or version specifiers)
            pkg_name=$(echo "$package_spec" | sed 's/\[.*\]//g' | sed 's/[><=!].*//g' | xargs)

            log "Reinstalling $pkg_name with $py_tool spec \"$package_spec\"..."
            if [[ "$py_tool" == "uv" ]]; then
                uv tool install --force --upgrade "$package_spec" ||
                    log "Failed to reinstall $pkg_name via uv." "WARNING"
            else
                pipx install --include-deps --force "$package_spec" ||
                    log "Failed to reinstall $pkg_name via pipx." "WARNING"
            fi
        done < requirements.txt
        log "Python packages updated successfully." "SUCCESS"
    else
        log "Neither pipx nor (on NO_ADMIN Linux) uv found. Skipping Python updates." "WARNING"
    fi
else
    log "requirements.txt not found. Skipping Python updates." "WARNING"
fi

# Upgrade Homebrew packages that are already installed. Installing a layer's
# Brewfile is the job of its make target, so this never adds new packages.
if command -v brew &> /dev/null; then
    log "Upgrading installed Homebrew packages..."
    if brew update && brew upgrade; then
        log "Homebrew packages upgraded successfully." "SUCCESS"
    else
        log "Homebrew upgrade reported errors." "WARNING"
    fi
else
    log "Homebrew not found. Skipping Homebrew updates." "WARNING"
fi

# Summary
echo ""
log "================================" "INFO"
log "Dependency update complete!" "SUCCESS"
log "================================" "INFO"
echo ""
log "Updated packages:" "INFO"
log "  - Python packages (from requirements.txt)" "INFO"
log "  - Homebrew packages (already-installed ones upgraded)" "INFO"
log "  - npm packages: reinstall via make targets" "INFO"
echo ""
log "Verification commands:" "INFO"
log "  pipx list / uv tool list   # Check Python packages" "INFO"
log "  brew list                  # Check Homebrew packages" "INFO"
log "  npm list -g --depth=0      # Check npm packages" "INFO"
echo ""
log "Test your Emacs setup to ensure everything works!" "WARNING"
