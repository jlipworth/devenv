#!/bin/bash
source common_utils.sh

if [[ -f "$GNU_DIR/versions.conf" ]]; then
    source "$GNU_DIR/versions.conf"
fi

set -euo pipefail

NEOVIM_VERSION="${NEOVIM_VERSION:-0.12.0}"
NEOVIM_MIN_VERSION="${NEOVIM_MIN_VERSION:-0.11.2}"
NEOVIM_BUILD_TYPE="${NEOVIM_BUILD_TYPE:-RelWithDebInfo}"
NEOVIM_PREFIX="${NEOVIM_PREFIX:-$HOME/.local/neovim}"
NEOVIM_SOURCE_ROOT="${NEOVIM_SOURCE_ROOT:-$HOME/.cache/devenv-builds}"
NEOVIM_TAR="neovim-v${NEOVIM_VERSION}.tar.gz"
NEOVIM_DIR="neovim-${NEOVIM_VERSION}"
CI="${CI:-false}"
CI_INSTALL="${CI_INSTALL:-false}"

DRY_RUN="false"
if [[ "${1:-}" == "--verify" || "${1:-}" == "--check" || "${1:-}" == "--dry-run" ]]; then
    DRY_RUN="true"
    log "Running in verification/dry-run mode. Will prepare bundled dependencies and configure only." "INFO"
fi

neovim_version_lt() {
    local IFS=.
    local lhs rhs
    local i
    read -r -a lhs <<< "$1"
    read -r -a rhs <<< "$2"

    for ((i = ${#lhs[@]}; i < ${#rhs[@]}; i++)); do
        lhs[i]=0
    done
    for ((i = ${#rhs[@]}; i < ${#lhs[@]}; i++)); do
        rhs[i]=0
    done

    for ((i = 0; i < ${#lhs[@]}; i++)); do
        if ((10#${lhs[i]} < 10#${rhs[i]})); then
            return 0
        fi
        if ((10#${lhs[i]} > 10#${rhs[i]})); then
            return 1
        fi
    done

    return 1
}

detect_linux_gcc_version() {
    local gcc_version
    if command -v gcc &> /dev/null; then
        gcc_version=$(gcc -dumpversion | cut -d. -f1)
    else
        for v in 14 13 12 11; do
            if command -v "gcc-$v" &> /dev/null; then
                gcc_version=$v
                break
            fi
        done
    fi
    echo "${gcc_version:-11}"
}

set_brew_toolchain_env() {
    local brew_prefix
    brew_prefix="$(brew --prefix)"
    export PATH="${brew_prefix}/bin:${brew_prefix}/sbin:$PATH"
    export PKG_CONFIG_PATH="${brew_prefix}/lib/pkgconfig:${brew_prefix}/share/pkgconfig:${PKG_CONFIG_PATH:-}"

    local binutils_prefix
    binutils_prefix="$(brew --prefix binutils 2> /dev/null || true)"
    if [[ -n "$binutils_prefix" && -d "$binutils_prefix" ]]; then
        if [[ -d "${binutils_prefix}/libexec/gnubin" ]]; then
            export PATH="${binutils_prefix}/libexec/gnubin:$PATH"
        elif [[ -d "${binutils_prefix}/bin" ]]; then
            export PATH="${binutils_prefix}/bin:$PATH"
        fi
        log "binutils tools configured from: $binutils_prefix"
    fi

    local gcc_prefix latest_gcc_executable gcc_major
    gcc_prefix="$(brew --prefix gcc 2> /dev/null || true)"
    latest_gcc_executable="$(ls -1 "${brew_prefix}"/bin/gcc-[0-9]* 2> /dev/null | sort -V | tail -n 1)"
    if [[ -n "$latest_gcc_executable" ]]; then
        gcc_major="$("$latest_gcc_executable" -dumpversion | cut -d. -f1)"
        export CC="gcc-${gcc_major}"
        export CXX="g++-${gcc_major}"
        if [[ -n "$gcc_prefix" && -d "${gcc_prefix}/lib/gcc/${gcc_major}" ]]; then
            export LIBRARY_PATH="${gcc_prefix}/lib/gcc/${gcc_major}:${LIBRARY_PATH:-}"
            export LD_LIBRARY_PATH="${gcc_prefix}/lib/gcc/${gcc_major}:${LD_LIBRARY_PATH:-}"
        fi
        log "Using compiler: CC=$CC, CXX=$CXX"
    fi
}

configure_no_admin_linux_env() {
    local gcc_version arch gcc_arch gcc_lib_path

    log "Homebrew not found and NO_ADMIN=true, so automatic dependency installation is disabled." "WARNING"
    log "Attempting to continue with preinstalled system dependencies already available on this machine." "WARNING"
    log "If configure fails, install or expose Linuxbrew first, or preinstall the Neovim build dependencies through your admin-approved path." "WARNING"

    gcc_version="$(detect_linux_gcc_version)"

    if command -v "gcc-${gcc_version}" &> /dev/null; then
        export CC="gcc-${gcc_version}"
    elif command -v gcc &> /dev/null; then
        export CC="gcc"
    fi

    if command -v "g++-${gcc_version}" &> /dev/null; then
        export CXX="g++-${gcc_version}"
    elif command -v g++ &> /dev/null; then
        export CXX="g++"
    fi

    if [[ -n "${CC:-}" || -n "${CXX:-}" ]]; then
        log "Using preinstalled compiler toolchain: CC=${CC:-unset}, CXX=${CXX:-unset}"
    fi

    arch="$(dpkg --print-architecture 2> /dev/null || uname -m)"
    case "$arch" in
        amd64 | x86_64) gcc_arch="x86_64-linux-gnu" ;;
        arm64 | aarch64) gcc_arch="aarch64-linux-gnu" ;;
        *) gcc_arch="$arch" ;;
    esac

    gcc_lib_path="/usr/lib/gcc/${gcc_arch}/${gcc_version}"
    if [[ -d "$gcc_lib_path" ]]; then
        export LD_LIBRARY_PATH="${gcc_lib_path}:${LD_LIBRARY_PATH:-}"
        export LIBRARY_PATH="${gcc_lib_path}:${LIBRARY_PATH:-}"
        export CPATH="${gcc_lib_path}/include:${CPATH:-}"
        export PKG_CONFIG_PATH="${gcc_lib_path}/pkgconfig:${PKG_CONFIG_PATH:-}"
        log "Using preinstalled GCC library path: $gcc_lib_path"
    fi
}

cmake_generator() {
    if command -v ninja &> /dev/null; then
        echo "Ninja"
    else
        echo "Unix Makefiles"
    fi
}

configure_neovim_build() {
    local generator
    generator="$(cmake_generator)"

    mkdir -p ".deps" build
    cmake -S cmake.deps -B .deps -G "$generator"
    cmake \
        -S . \
        -B build \
        -G "$generator" \
        -D CMAKE_BUILD_TYPE="${NEOVIM_BUILD_TYPE}" \
        -D CMAKE_INSTALL_PREFIX="${NEOVIM_PREFIX}"
}

ensure_build_dependencies() {
    if [[ "$OS" == "Linux" && "$DISTRO" == "arch" ]]; then
        log "Installing Neovim source-build dependencies on Arch Linux…"

        local pacman_cmd="sudo pacman"
        if [[ "$CI" == "true" ]] || [[ $(id -u) -eq 0 ]]; then
            pacman_cmd="pacman"
        fi

        $pacman_cmd -Sy
        $pacman_cmd -S --needed --noconfirm \
            base-devel cmake ninja curl git gettext ccache pkgconf
        log "Dependencies installed successfully" "SUCCESS"
        return 0
    fi

    if [[ "$OS" == "Linux" ]]; then
        local brew_bin
        brew_bin="$(find_brew_bin || true)"
        if [[ -n "$brew_bin" ]]; then
            eval "$("$brew_bin" shellenv)"
            log "Installing Neovim source-build dependencies via Linuxbrew…"
            brew bundle --file="$GNU_DIR/brewfiles/Brewfile.neovim-build"
            if ! command -v cc &> /dev/null && ! command -v gcc &> /dev/null; then
                log "No compiler detected after Brewfile install; installing gcc via Linuxbrew…"
                brew install gcc
            fi
            set_brew_toolchain_env
            log "Dependencies installed via Linuxbrew successfully" "SUCCESS"
            return 0
        fi

        if no_admin_mode; then
            configure_no_admin_linux_env
            return 0
        fi

        log "Homebrew not found, falling back to apt (requires sudo)…" "WARNING"
        local apt_cmd="sudo apt"
        if [[ "$CI" == "true" ]] || [[ $(id -u) -eq 0 ]]; then
            apt_cmd="apt"
        fi
        $apt_cmd update
        $apt_cmd install -y \
            build-essential cmake ninja-build curl git gettext ccache pkg-config

        local gcc_version
        gcc_version="$(detect_linux_gcc_version)"
        if command -v "gcc-${gcc_version}" &> /dev/null; then
            export CC="gcc-${gcc_version}"
        fi
        if command -v "g++-${gcc_version}" &> /dev/null; then
            export CXX="g++-${gcc_version}"
        fi
        log "Dependencies installed successfully" "SUCCESS"
        return 0
    fi

    if [[ "$OS" == "Darwin" ]]; then
        log "Checking for Xcode CLI tools…"
        if ! xcode-select -p &> /dev/null; then
            log "Xcode Command Line Tools missing. Install with 'xcode-select --install' and retry." "ERROR"
            exit 1
        fi

        log "Installing Neovim source-build dependencies on macOS via Brewfile…"
        brew bundle --file="$GNU_DIR/brewfiles/Brewfile.neovim-build"
        set_brew_toolchain_env
        log "Dependencies installed successfully" "SUCCESS"
        return 0
    fi
}

verify_required_commands() {
    local missing=0
    for cmd in git curl make cmake tar; do
        if ! command -v "$cmd" &> /dev/null; then
            log "Missing required command: $cmd" "ERROR"
            missing=1
        fi
    done

    if ! command -v ninja &> /dev/null; then
        log "ninja is not installed. The build can proceed, but it may be slower." "WARNING"
    fi

    if ! command -v ccache &> /dev/null; then
        log "ccache is not installed. Rebuilds will be slower." "WARNING"
    fi

    if ! command -v msgfmt &> /dev/null && ! command -v gettext &> /dev/null; then
        log "gettext/msgfmt is required to build Neovim from source." "ERROR"
        missing=1
    fi

    if ! command -v cc &> /dev/null && ! command -v gcc &> /dev/null; then
        log "A C compiler is required to build Neovim from source." "ERROR"
        missing=1
    fi

    [[ "$missing" -eq 0 ]]
}

run_nvim_make() {
    local target="${1:-}"
    local nproc make_cmd
    make_cmd=(
        make
        "CMAKE_BUILD_TYPE=${NEOVIM_BUILD_TYPE}"
        "CMAKE_EXTRA_FLAGS=-DCMAKE_INSTALL_PREFIX=${NEOVIM_PREFIX}"
    )

    if ! command -v ninja &> /dev/null; then
        if [[ "$OS" == "Darwin" ]]; then
            nproc=$(sysctl -n hw.ncpu)
        else
            nproc=$(nproc)
        fi
        make_cmd+=("-j${nproc}")
    fi

    if [[ -n "$target" ]]; then
        make_cmd+=("$target")
    fi

    "${make_cmd[@]}"
}

run_nvim_make_with_retry() {
    local target="${1:-}"
    local attempt max_attempts
    max_attempts=2

    for ((attempt = 1; attempt <= max_attempts; attempt++)); do
        if run_nvim_make "$target"; then
            return 0
        fi

        if ((attempt < max_attempts)); then
            log "Neovim build command failed (attempt ${attempt}/${max_attempts}); retrying once after a short delay..." "WARNING"
            sleep 5
        fi
    done

    return 1
}

build_configured_neovim() {
    local nproc

    if command -v ninja &> /dev/null; then
        cmake --build build
        return 0
    fi

    if [[ "$OS" == "Darwin" ]]; then
        nproc=$(sysctl -n hw.ncpu)
    else
        nproc=$(nproc)
    fi

    cmake --build build --parallel "$nproc"
}

link_nvim_config() {
    local nvim_config_dir="$HOME/.config/nvim"
    local nvim_source="$GNU_DIR/nvim"

    mkdir -p "$HOME/.config"

    if [ -L "$nvim_config_dir" ]; then
        log "A symbolic link already exists at $nvim_config_dir. Replacing it."
        rm "$nvim_config_dir"
    elif [ -d "$nvim_config_dir" ]; then
        log "A directory exists at $nvim_config_dir. Backing it up."
        mv "$nvim_config_dir" "${nvim_config_dir}_backup_$(date +%Y%m%d%H%M%S)"
    elif [ -e "$nvim_config_dir" ]; then
        log "A non-directory file exists at $nvim_config_dir. Backing it up."
        mv "$nvim_config_dir" "${nvim_config_dir}_backup_$(date +%Y%m%d%H%M%S)"
    fi

    ln -s "$nvim_source" "$nvim_config_dir"
    log "Neovim config symlinked: $nvim_config_dir -> $nvim_source" "SUCCESS"
}

install_lazygit_companion() {
    if is_installed "lazygit"; then
        log "lazygit is already installed."
        return 0
    fi

    log "Installing lazygit companion tool..."
    if is_installed "brew"; then
        brew install lazygit || log "Error installing lazygit via Homebrew." "WARNING"
    elif [[ "$DISTRO" == "arch" ]] && ! no_admin_mode; then
        install_packages "lazygit"
    else
        log "lazygit is not installed. Install it separately for <leader>gg support." "WARNING"
    fi
}

log "Preparing Neovim ${NEOVIM_VERSION} source build..."
log "Install prefix: $NEOVIM_PREFIX"

if [[ "$CI" == "true" ]]; then
    log "Running in CI mode" "INFO"
fi

ensure_build_dependencies
verify_required_commands || exit 1

mkdir -p "$NEOVIM_SOURCE_ROOT"
cd "$NEOVIM_SOURCE_ROOT"

log "Checking for existing Neovim source directory..."
if [[ -d "$NEOVIM_DIR" ]]; then
    if [[ "$CI" == "true" ]]; then
        log "CI mode: Removing existing source directory for clean build" "INFO"
        rm -rf "$NEOVIM_DIR" "$NEOVIM_TAR"
    elif [[ ! -t 0 ]]; then
        log "Non-interactive shell detected. Reusing '$NEOVIM_DIR' and cleaning previous build outputs…" "INFO"
        make -C "$NEOVIM_DIR" distclean > /dev/null 2>&1 || true
        rm -rf "$NEOVIM_DIR/build"
    else
        read -p "Directory '$NEOVIM_DIR' exists. Redownload & replace? [y/N] " resp
        if [[ "$resp" =~ ^[Yy]$ ]]; then
            rm -rf "$NEOVIM_DIR" "$NEOVIM_TAR"
        else
            make -C "$NEOVIM_DIR" distclean > /dev/null 2>&1 || true
            rm -rf "$NEOVIM_DIR/build"
        fi
    fi
fi

if [[ ! -d "$NEOVIM_DIR" ]]; then
    log "Downloading Neovim ${NEOVIM_VERSION} source tarball..."
    curl -fsSL "https://github.com/neovim/neovim/archive/refs/tags/v${NEOVIM_VERSION}.tar.gz" -o "$NEOVIM_TAR"
    log "Download complete. Extracting..."
    mkdir -p "$NEOVIM_DIR"
    tar -xzf "$NEOVIM_TAR" -C "$NEOVIM_DIR" --strip-components=1
    log "Extraction complete" "SUCCESS"
else
    log "Using existing source directory: $NEOVIM_DIR"
fi

cd "$NEOVIM_DIR"

log "Preparing bundled Neovim dependencies..."
run_nvim_make_with_retry deps
log "Dependency preparation finished." "SUCCESS"

log "Configuring Neovim build (build type: $NEOVIM_BUILD_TYPE)..."
configure_neovim_build
log "Configure completed." "SUCCESS"

if [[ "$DRY_RUN" == "true" ]]; then
    log "Verification mode completed successfully. Dependency prep and configure passed. Skipping Neovim compilation and installation." "SUCCESS"
    exit 0
fi

log "Compiling Neovim (build type: $NEOVIM_BUILD_TYPE)..."
log "Started compilation at: $(date)"
build_configured_neovim
log "Compilation finished at: $(date)" "SUCCESS"

if [[ "$CI" == "true" && "$CI_INSTALL" != "true" ]]; then
    log "CI mode: Skipping 'make install' (set CI_INSTALL=true to install)" "INFO"
    VIMRUNTIME=runtime ./build/bin/nvim --version
    log "Neovim ${NEOVIM_VERSION} build verification successful!" "SUCCESS"
    exit 0
fi

log "Installing Neovim to $NEOVIM_PREFIX..."
mkdir -p "$NEOVIM_PREFIX" "$HOME/.local/bin"
cmake --install build

if [[ ! -x "$NEOVIM_PREFIX/bin/nvim" ]]; then
    log "Installation completed, but no Neovim binary was found at $NEOVIM_PREFIX/bin/nvim." "ERROR"
    exit 1
fi

installed_version="$("$NEOVIM_PREFIX/bin/nvim" --version | head -1 | sed -E 's/^NVIM v([0-9]+(\.[0-9]+){1,2}).*/\1/')"
if [[ -z "$installed_version" ]]; then
    log "Installed Neovim exists, but its version could not be determined." "ERROR"
    exit 1
fi
if neovim_version_lt "$installed_version" "$NEOVIM_MIN_VERSION"; then
    log "Neovim $installed_version is too old for LazyVim. Require >= $NEOVIM_MIN_VERSION." "ERROR"
    exit 1
fi

ln -sf "$NEOVIM_PREFIX/bin/nvim" "$HOME/.local/bin/nvim"
add_to_path "$HOME/.local/bin" "Neovim"
log "Neovim source build installed: $("$NEOVIM_PREFIX/bin/nvim" --version | head -1)" "SUCCESS"

install_lazygit_companion
link_nvim_config

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo " Neovim ${NEOVIM_VERSION} built successfully from source!"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo " Recommended next step:"
echo "   nvim    # first launch will bootstrap LazyVim plugins and Mason tools"
echo ""
