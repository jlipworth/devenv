#!/usr/bin/env bash
# Bootstrap script for devenv
# Usage: curl -fsSL https://raw.githubusercontent.com/jlipworth/devenv/master/bootstrap.sh | bash

set -euo pipefail

REPO_URL="https://github.com/jlipworth/devenv.git"
INSTALL_DIR="${GNU_FILES_DIR:-$HOME/GNU_files}"

echo "=== devenv bootstrap ==="
echo "Installing to: $INSTALL_DIR"

# Check for git
if ! command -v git &> /dev/null; then
    echo "Error: git is required but not installed."
    exit 1
fi

# Check for make
if ! command -v make &> /dev/null; then
    echo "Error: make is required but not installed."
    exit 1
fi

# Clone or update repo
if [[ -d "$INSTALL_DIR/.git" ]]; then
    echo "Existing installation found. Updating..."
    cd "$INSTALL_DIR"
    git pull --ff-only
else
    echo "Cloning devenv..."
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

echo ""
echo "=== Repository ready ==="
echo ""
echo "Run one of the following:"
echo "  cd $INSTALL_DIR && make spacemacs     # Emacs + Spacemacs"
echo "  cd $INSTALL_DIR && make full-setup    # Complete installation (all layers)"
echo "  cd $INSTALL_DIR && make help          # Show all options"
echo ""
echo "Install Emacs + Spacemacs now? [y/N]"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    make spacemacs
fi
