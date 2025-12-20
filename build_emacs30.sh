#!/bin/bash
source common_utils.sh

# Source pinned versions
if [[ -f "versions.conf" ]]; then
    source versions.conf
fi
EMACS_VERSION="${EMACS_VERSION:-30.1}"

set -e
EMACS_TAR="emacs-${EMACS_VERSION}.tar.gz"
EMACS_DIR="emacs-${EMACS_VERSION}"

# -----------------------------------------------------------------------------
# CI Mode Detection
# Set CI=true in your CI environment to:
#   - Skip interactive prompts (always start fresh)
#   - Skip sudo make install (just verify it compiles)
#   - Skip Spacemacs installation
#   - Expect dependencies to be pre-installed by CI
#
# Set CI_INSTALL=true to run 'make install' even in CI mode
# (useful for integration tests that need the installed binary)
# -----------------------------------------------------------------------------
CI="${CI:-false}"
CI_INSTALL="${CI_INSTALL:-false}"

if [[ "$CI" == "true" ]]; then
    log "Running in CI mode" "INFO"
fi

# -----------------------------------------------------------------------------
# 1) Install dependencies
# -----------------------------------------------------------------------------

# Function to detect available GCC version on Linux
detect_linux_gcc_version() {
    local gcc_version
    # Try to find the highest installed gcc version
    if command -v gcc &> /dev/null; then
        gcc_version=$(gcc -dumpversion | cut -d. -f1)
    else
        # Fallback: check for versioned gcc binaries
        for v in 14 13 12 11; do
            if command -v "gcc-$v" &> /dev/null; then
                gcc_version=$v
                break
            fi
        done
    fi
    echo "${gcc_version:-11}"
}

if [[ "$OS" == "Linux" ]]; then
    # Determine if we need sudo (CI containers run as root)
    if [[ "$CI" == "true" ]] || [[ $(id -u) -eq 0 ]]; then
        APT_CMD="apt"
    else
        APT_CMD="sudo apt"
    fi

    log "Installing dependencies on Linux…"
    $APT_CMD update

    # First install build-essential to get default gcc
    $APT_CMD install -y build-essential

    # Detect GCC version to install matching libgccjit
    # If GCC_VERSION is "auto" or unset, detect it dynamically
    if [[ "$GCC_VERSION" == "auto" || -z "$GCC_VERSION" ]]; then
        GCC_VERSION=$(detect_linux_gcc_version)
    fi
    log "Detected GCC version: $GCC_VERSION"

    # Install packages with dynamically detected GCC version
    log "Installing build packages..."
    $APT_CMD install -y \
        cmake pkg-config libgtk-3-dev libgnutls28-dev \
        libxpm-dev libncurses-dev libharfbuzz-dev libtree-sitter-dev \
        wget tar "libgccjit-${GCC_VERSION}-dev" autoconf automake texinfo libsqlite3-dev libx11-dev \
        libxft-dev libcairo2-dev libmagickwand-dev libvterm-dev libxml2-dev \
        libwebp-dev liblcms2-dev "gcc-${GCC_VERSION}" "g++-${GCC_VERSION}" \
        ca-certificates git
    log "Dependencies installed successfully" "SUCCESS"

    export CC="gcc-${GCC_VERSION}"
    export CXX="g++-${GCC_VERSION}"
    log "Using compiler: CC=$CC, CXX=$CXX"

    # Dynamically find GCC library paths based on architecture
    ARCH=$(dpkg --print-architecture 2> /dev/null || uname -m)
    log "Detected architecture: $ARCH"
    case "$ARCH" in
        amd64 | x86_64) GCC_ARCH="x86_64-linux-gnu" ;;
        arm64 | aarch64) GCC_ARCH="aarch64-linux-gnu" ;;
        *) GCC_ARCH="$ARCH" ;;
    esac

    GCC_LIB_PATH="/usr/lib/gcc/${GCC_ARCH}/${GCC_VERSION}"
    if [[ -d "$GCC_LIB_PATH" ]]; then
        export LD_LIBRARY_PATH="${GCC_LIB_PATH}:${LD_LIBRARY_PATH:-}"
        export LIBRARY_PATH="${GCC_LIB_PATH}:${LIBRARY_PATH:-}"
        export CPATH="${GCC_LIB_PATH}/include:${CPATH:-}"
        export PKG_CONFIG_PATH="${GCC_LIB_PATH}/pkgconfig:${PKG_CONFIG_PATH:-}"
        log "GCC library paths configured: $GCC_LIB_PATH"
    else
        log "Warning: GCC library path not found at $GCC_LIB_PATH" "WARNING"
    fi

elif [[ "$OS" == "Darwin" ]]; then
    log "Checking for Xcode CLI tools…"
    if ! xcode-select -p &> /dev/null; then
        log "Xcode Command Line Tools missing. Install with 'xcode-select --install' and retry." "ERROR"
        exit 1
    fi

    log "Installing dependencies on macOS via Brewfile…"
    brew bundle --file="$GNU_DIR/brewfiles/Brewfile.emacs-30"

    # Ensure Homebrew binaries (giflib-config, tiffinfo, etc.) are on PATH
    export PATH="$(brew --prefix)/bin:$(brew --prefix)/sbin:$PATH"

    # Let configure find libgccjit
    # Find the latest versioned gcc executable (e.g., /opt/homebrew/bin/gcc-15)
    LATEST_GCC_EXECUTABLE=$(ls -1 /opt/homebrew/bin/gcc-[0-9]* | sort -V | tail -n 1)

    # Ask that executable for its version and extract the major number
    LATEST_GCC_MAJOR_VERSION=$(${LATEST_GCC_EXECUTABLE} -dumpversion | cut -d. -f1)

    # Now, set the paths using the dynamically found information
    HOMEBREW_GCC_PREFIX="$(brew --prefix gcc)"
    export PKG_CONFIG_PATH="${HOMEBREW_GCC_PREFIX}/lib/gcc/${LATEST_GCC_MAJOR_VERSION}/pkgconfig:$PKG_CONFIG_PATH"
    export LIBRARY_PATH="${HOMEBREW_GCC_PREFIX}/lib/gcc/${LATEST_GCC_MAJOR_VERSION}:$LIBRARY_PATH"
fi

# -----------------------------------------------------------------------------
# 2) Fetch & unpack Emacs (with directory check + cleanup)
# -----------------------------------------------------------------------------
log "Checking for existing Emacs source directory..."
if [[ -d "$EMACS_DIR" ]]; then
    if [[ "$CI" == "true" ]]; then
        # In CI, always start fresh
        log "CI mode: Removing existing source directory for clean build" "INFO"
        rm -rf "$EMACS_DIR" "$EMACS_TAR"
    else
        read -p "Directory '$EMACS_DIR' exists. Redownload & replace? [y/N] " resp
        if [[ "$resp" =~ ^[Yy]$ ]]; then
            log "Removing old source…" "INFO"
            rm -rf "$EMACS_DIR" "$EMACS_TAR"
        else
            log "Reusing '$EMACS_DIR'. Cleaning previous build…" "INFO"
            make -C "$EMACS_DIR" distclean > /dev/null 2>&1 || make -C "$EMACS_DIR" clean > /dev/null 2>&1 || true
        fi
    fi
fi

if [[ ! -d "$EMACS_DIR" ]]; then
    log "Downloading Emacs ${EMACS_VERSION} from GNU FTP..."
    if [[ "$OS" == "Darwin" ]]; then
        curl -fsSL "https://ftp.gnu.org/gnu/emacs/${EMACS_TAR}" -o "${EMACS_TAR}"
    else
        wget -q "https://ftp.gnu.org/gnu/emacs/${EMACS_TAR}"
    fi
    log "Download complete. Extracting..."
    tar -xzf "${EMACS_TAR}"
    log "Extraction complete" "SUCCESS"
else
    log "Using existing source directory: $EMACS_DIR"
fi

cd "${EMACS_DIR}"

# -----------------------------------------------------------------------------
# 3) Configure
# -----------------------------------------------------------------------------
log "Configuring the build…"
if [[ "$OS" == "Darwin" ]]; then
    ./configure \
        --with-native-compilation \
        --with-tree-sitter \
        --with-threads \
        --with-sqlite3 \
        --with-modules \
        --with-cairo \
        --with-imagemagick \
        --with-gnutls \
        --with-rsvg \
        --with-harfbuzz \
        --with-xml2 \
        --with-webp \
        --with-lcms2 \
        --with-ns \
        --disable-ns-self-contained
else
    ./configure \
        --with-native-compilation \
        --with-tree-sitter \
        --with-threads \
        --with-sqlite3 \
        --with-x \
        --with-cairo \
        --with-modules \
        --with-imagemagick \
        --with-harfbuzz \
        --with-gnutls \
        --with-pgtk \
        --with-xml2 \
        --with-webp \
        --with-lcms2 \
        --with-vterm
fi
log "Configure completed." "SUCCESS"

# -----------------------------------------------------------------------------
# 4) Build & Install
# -----------------------------------------------------------------------------
log "Compiling Emacs (this may take 20-40 minutes)..."
log "Started compilation at: $(date)"
if [[ "$OS" == "Darwin" ]]; then
    NPROC=$(sysctl -n hw.ncpu)
else
    NPROC=$(nproc)
fi
log "Using $NPROC parallel jobs"
make -j"$NPROC"
log "Compilation finished at: $(date)" "SUCCESS"

# In CI mode, skip installation unless CI_INSTALL=true
if [[ "$CI" == "true" && "$CI_INSTALL" != "true" ]]; then
    log "CI mode: Skipping 'make install' (set CI_INSTALL=true to install)" "INFO"
else
    log "Installing Emacs to system..."
    if [[ "$CI" == "true" ]]; then
        # In CI containers, we run as root - no sudo needed
        make install
    else
        sudo make install
    fi
    log "System installation complete" "SUCCESS"

    if [[ "$OS" == "Darwin" ]]; then
        log "Building Emacs.app bundle…"
        make -C nextstep install
        log "Emacs.app created in nextstep/" "SUCCESS"
    fi
fi

# -----------------------------------------------------------------------------
# 5) Verify build
# -----------------------------------------------------------------------------
log "Verifying Emacs build..."
if [[ "$CI" == "true" && "$CI_INSTALL" != "true" ]]; then
    # In CI without install, use the locally built binary
    ./src/emacs --version
    ./src/emacs --batch --eval "(message \"Emacs %s with native-comp works!\" emacs-version)"
    log "Emacs ${EMACS_VERSION} build verification successful!" "SUCCESS"
else
    # Use installed system binary
    emacs --version
    emacs --batch --eval "(message \"Emacs %s with native-comp works!\" emacs-version)"
    log "Emacs ${EMACS_VERSION} installed successfully!" "SUCCESS"
fi

# -----------------------------------------------------------------------------
# Post-build guidance (skip in CI)
# -----------------------------------------------------------------------------
if [[ "$CI" != "true" ]]; then
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo " Emacs ${EMACS_VERSION} built successfully!"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo " RECOMMENDED NEXT STEPS:"
    echo ""
    echo " 1. Install base prerequisites (required for most layers):"
    echo "    make system-prereq"
    echo ""
    echo " 2. Install additional layers as needed:"
    echo "    make help           # See all available layers"
    echo ""
    echo " NOTE: Most layers require Node.js and/or pipx."
    echo "       Run 'make system-prereq' first if not already installed."
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
fi

# -----------------------------------------------------------------------------
# 6) Optionally bootstrap Spacemacs (skip in CI)
# -----------------------------------------------------------------------------
if [[ "$CI" == "true" ]]; then
    log "CI mode: Skipping Spacemacs installation" "INFO"
    log "Build completed successfully!" "SUCCESS"
    exit 0
fi

if [ -d "$HOME/.emacs.d" ]; then
    log "Existing ~/.emacs.d detected." "WARNING"
    read -p "Replace with Spacemacs? [y/N] " answer
    [[ "$answer" == "y" ]] || {
        log "Skipping Spacemacs install."
        exit 0
    }
    rm -rf "$HOME/.emacs.d"
fi

log "Cloning Spacemacs repository (develop branch)..."
git clone --depth 100 --branch develop https://github.com/syl20bnr/spacemacs "$HOME/.emacs.d" &&
    log "Spacemacs installed." "SUCCESS" ||
    {
        log "Failed to clone Spacemacs." "ERROR"
        exit 1
    }
