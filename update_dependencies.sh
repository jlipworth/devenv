#!/bin/bash
# Update all dependencies after merging Renovate MRs
# Run this after pulling/merging dependency updates from git

source common_utils.sh
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

# Update Python packages
if [[ -f "requirements.txt" ]]; then
    log "Updating Python packages..."
    if command -v pipx &> /dev/null; then
        while IFS= read -r package || [ -n "$package" ]; do
            # Skip empty lines and comments
            [[ -z "$package" || "$package" =~ ^# ]] && continue

            package_spec=$(echo "$package" | xargs)

            # Extract package name (before [extras] or version specifiers)
            pkg_name=$(echo "$package_spec" | sed 's/\[.*\]//g' | sed 's/[><=!].*//g' | xargs)

            log "Reinstalling $pkg_name with pipx spec \"$package_spec\"..."
            pipx install --include-deps --force "$package_spec" ||
                log "Failed to reinstall $pkg_name via pipx." "WARNING"
        done < requirements.txt
        log "Python packages updated successfully." "SUCCESS"
    else
        log "pipx not found. Skipping Python updates." "WARNING"
    fi
else
    log "requirements.txt not found. Skipping Python updates." "WARNING"
fi

# Update Homebrew packages from brewfiles/ directory
if [[ -d "$REPO_DIR/brewfiles" ]]; then
    log "Updating Homebrew packages from brewfiles/..."
    if command -v brew &> /dev/null; then
        for brewfile in "$REPO_DIR/brewfiles"/Brewfile.*; do
            if [[ -f "$brewfile" ]]; then
                log "Installing from $(basename "$brewfile")..."
                brew bundle install --file="$brewfile" || log "Error with $(basename "$brewfile")" "WARNING"
            fi
        done
        log "Homebrew packages updated successfully." "SUCCESS"
    else
        log "Homebrew not found. Skipping Homebrew updates." "WARNING"
    fi
else
    log "brewfiles/ directory not found. Skipping Homebrew updates." "WARNING"
fi

# Summary
echo ""
log "================================" "INFO"
log "Dependency update complete!" "SUCCESS"
log "================================" "INFO"
echo ""
log "Updated packages:" "INFO"
log "  - Python packages (from requirements.txt)" "INFO"
log "  - Homebrew packages (from brewfiles/)" "INFO"
log "  - npm packages: reinstall via make targets" "INFO"
echo ""
log "Verification commands:" "INFO"
log "  pipx list                  # Check Python packages" "INFO"
log "  brew list                  # Check Homebrew packages" "INFO"
log "  npm list -g --depth=0      # Check npm packages" "INFO"
echo ""
log "Test your Emacs setup to ensure everything works!" "WARNING"
