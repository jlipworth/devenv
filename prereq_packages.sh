#!/bin/bash

source common_utils.sh

# =============================================================================
# Arch Linux Package Mappings
# Maps Debian package names to Arch equivalents.
# Keep this bash-3 compatible for macOS' system bash.
# =============================================================================
translate_arch_pkg() {
    local pkg="$1"
    case "$pkg" in
        # Dev libraries
        libsecret-1-0 | libsecret-1-dev) echo "libsecret" ;;
        libcurl4-openssl-dev) echo "curl" ;;
        libssl-dev) echo "openssl" ;;
        libxml2-dev) echo "libxml2" ;;
        # R language
        r-base | r-base-dev) echo "r" ;;
        # LaTeX
        texlive-latex-extra) echo "texlive-latexextra" ;;
        # System tools
        cups-client) echo "cups" ;;
        lpr) echo "" ;; # Part of cups on Arch
        libtool-bin) echo "libtool" ;;
        python3-pip) echo "python-pip" ;;
        lldb) echo "lldb" ;;
        xclip) echo "xclip" ;;
        # Audio (Whisper)
        libasound2-plugins) echo "alsa-plugins" ;;
        *) echo "$pkg" ;;
    esac
}

# Translate package name for current distro
translate_pkg() {
    local pkg="$1"
    if [[ "$DISTRO" == "arch" ]]; then
        translate_arch_pkg "$pkg"
    else
        echo "$pkg"
    fi
}

# Install packages with automatic translation
install_packages_translated() {
    local pkgs=()
    for pkg in "$@"; do
        local translated
        translated=$(translate_pkg "$pkg")
        if [[ -n "$translated" ]]; then
            pkgs+=("$translated")
        fi
    done
    if [[ ${#pkgs[@]} -gt 0 ]]; then
        install_packages "${pkgs[@]}"
    fi
}

# WSL-specific setup
setup_wsl_config() {
    if grep -q WSL /proc/version; then
        log "Checking WSL configuration..."
        # Check if /etc/wsl.conf contains the appendwindowspath setting
        if grep -q "appendwindowspath = false" /etc/wsl.conf 2> /dev/null; then
            log "WSL configuration already set. No changes made."
        else
            log "Configuring WSL to disable Windows PATH inheritance..."
            if [[ -w /etc/wsl.conf ]] || [[ $(id -u) -eq 0 ]]; then
                echo -e "[interop]\nappendwindowspath = false" | tee -a /etc/wsl.conf
            elif [[ "$NO_ADMIN" == "true" ]]; then
                log "NO_ADMIN=true: not modifying /etc/wsl.conf automatically." "WARNING"
                log "To disable Windows PATH inheritance, manually add to /etc/wsl.conf:" "WARNING"
                log "  [interop]" "WARNING"
                log "  appendwindowspath = false" "WARNING"
                return 0
            elif command -v sudo &> /dev/null; then
                echo -e "[interop]\nappendwindowspath = false" | sudo tee -a /etc/wsl.conf
            else
                log "Cannot write to /etc/wsl.conf (no sudo available)." "WARNING"
                log "To disable Windows PATH inheritance, manually add to /etc/wsl.conf:" "WARNING"
                log "  [interop]" "WARNING"
                log "  appendwindowspath = false" "WARNING"
                return 0
            fi
            log "WSL configuration updated successfully."
        fi
    fi
}

# Install WSL utilities (wslu) for browser integration
install_wsl_utils() {
    if grep -q WSL /proc/version 2> /dev/null; then
        if ! is_installed "wslview"; then
            log "Installing wslu for WSL browser integration..."
            if is_installed "brew"; then
                # Prefer Homebrew (no sudo required)
                brew install wslutilities/wslu/wslu || log "Error installing wslu via brew." "WARNING"
            elif [[ "$NO_ADMIN" == "true" ]]; then
                log "NO_ADMIN=true: skipping wslu installation because it would require a system package manager." "WARNING"
            elif command -v sudo &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y wslu
            else
                log "Cannot install wslu: no brew or sudo available." "WARNING"
                log "Install Homebrew first, or ask IT to run: apt install wslu" "WARNING"
            fi
        else
            log "wslu is already installed."
        fi
    else
        log "Not running on WSL, skipping wslu installation."
    fi
}

# Install Homebrew on Linux
install_homebrew() {
    if [[ "$OS" == "Linux" ]]; then
        local brew_bin=""

        brew_bin="$(find_brew_bin || true)"

        if [[ -n "$brew_bin" ]]; then
            log "Homebrew is already installed at $brew_bin"
            eval "$("$brew_bin" shellenv)"
            add_to_shell_rc "eval \"\$($brew_bin shellenv)\"" "Homebrew (Linux)"
            return 0
        fi

        if [[ "$NO_ADMIN" == "true" ]]; then
            log "NO_ADMIN=true: not attempting Homebrew bootstrap automatically." "WARNING"
            log "Install or expose an existing Linuxbrew manually, then rerun this target." "WARNING"
            log "Expected common locations: /home/linuxbrew/.linuxbrew or ~/.linuxbrew" "WARNING"
            return 0
        fi

        if ! is_installed "brew"; then
            log "Installing Homebrew for Linux..."
            CI=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            brew_bin="$(find_brew_bin || true)"
            if [[ -n "$brew_bin" ]]; then
                eval "$("$brew_bin" shellenv)"
                add_to_shell_rc "eval \"\$($brew_bin shellenv)\"" "Homebrew (Linux)"
            else
                log "Homebrew installer finished, but brew was not found in the expected locations." "WARNING"
            fi
        else
            log "Homebrew is already installed."
        fi
    fi
}

ensure_uv_installed() {
    if is_installed "uv"; then
        return 0
    fi

    log "Installing uv..."
    if is_installed "brew"; then
        brew install uv || log "Brew install for uv failed, falling back to official installer." "WARNING"
    fi

    if ! is_installed "uv"; then
        curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh || {
            log "Failed to install uv." "ERROR"
            return 1
        }
        export PATH="$HOME/.local/bin:$PATH"
        add_to_path "$HOME/.local/bin" "uv"
    fi

    return 0
}

# Install NodeJS and NPM via nvm for version management
install_nodejs() {
    log "Installing Node.js via nvm..."

    # Source versions.conf for NODE_VERSION
    source "$GNU_DIR/versions.conf"
    local node_version="${NODE_VERSION:-22}"

    # Set up NVM_DIR
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

    # nvm is sensitive to npm prefix overrides; clear them for the entire nvm
    # bootstrap/install flow, then restore them afterward.
    local saved_npm_config_prefix="${npm_config_prefix-}"
    local saved_NPM_CONFIG_PREFIX="${NPM_CONFIG_PREFIX-}"
    unset npm_config_prefix
    unset NPM_CONFIG_PREFIX

    # Install nvm if not present
    if [[ ! -d "$NVM_DIR" ]]; then
        log "Installing nvm..."
        curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash || {
            log "Failed to install nvm." "ERROR"
            return 1
        }
    else
        log "nvm is already installed at $NVM_DIR"
    fi

    # Source nvm for current shell session
    # shellcheck source=/dev/null
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

    if ! command -v nvm &> /dev/null; then
        [[ -n "${saved_npm_config_prefix}" ]] && export npm_config_prefix="$saved_npm_config_prefix"
        [[ -n "${saved_NPM_CONFIG_PREFIX}" ]] && export NPM_CONFIG_PREFIX="$saved_NPM_CONFIG_PREFIX"
        log "nvm command not available after installation." "ERROR"
        return 1
    fi

    # Install specified Node version
    log "Installing Node.js v${node_version}..."
    nvm install "$node_version" || {
        [[ -n "${saved_npm_config_prefix}" ]] && export npm_config_prefix="$saved_npm_config_prefix"
        [[ -n "${saved_NPM_CONFIG_PREFIX}" ]] && export NPM_CONFIG_PREFIX="$saved_NPM_CONFIG_PREFIX"
        log "Failed to install Node.js v${node_version}." "ERROR"
        return 1
    }

    # Set as default
    nvm alias default "$node_version"
    nvm use default

    [[ -n "${saved_npm_config_prefix}" ]] && export npm_config_prefix="$saved_npm_config_prefix"
    [[ -n "${saved_NPM_CONFIG_PREFIX}" ]] && export NPM_CONFIG_PREFIX="$saved_NPM_CONFIG_PREFIX"

    # Verify installation
    log "Node.js $(node --version) installed successfully." "SUCCESS"
    log "npm $(npm --version) available."

    # Persist the user-local npm global bin dir so npm-installed language
    # servers and tools are available in future shells, not just this process.
    add_to_path "${HOME}/.npm-global/bin" "npm global binaries"

    # Update npm to latest
    npm install -g npm@latest || log "Failed to update npm." "WARNING"
}

install_git_credential() {
    build_git_credential_helper() {
        local source_dir="$1"
        local build_dir

        if [[ ! -d "$source_dir" ]]; then
            log "Git credential helper source directory not found: $source_dir" "WARNING"
            return 1
        fi

        if [[ ! -f "$source_dir/Makefile" ]]; then
            log "Git credential helper source directory exists but has no Makefile: $source_dir" "WARNING"
            return 1
        fi

        build_dir="$(mktemp -d)" || {
            log "Failed to create temporary build directory for git credential helper." "ERROR"
            return 1
        }

        cp -R "$source_dir"/. "$build_dir"/ || {
            log "Failed to copy git credential helper source from $source_dir" "ERROR"
            rm -rf "$build_dir"
            return 1
        }

        make -C "$build_dir" || {
            log "Failed to build git credential helper from copied source." "ERROR"
            rm -rf "$build_dir"
            return 1
        }

        cp "$build_dir/git-credential-libsecret" "$HOME/.local/bin" || {
            log "Failed to copy git credential helper to ~/.local/bin" "ERROR"
            rm -rf "$build_dir"
            return 1
        }
        chmod +x "$HOME/.local/bin/git-credential-libsecret"
        rm -rf "$build_dir"
        return 0
    }

    if [[ "$OS" == "Linux" ]]; then
        log "Installing Git credential helper for Linux..."
        mkdir -p "$HOME/.local/bin"
        add_to_path "$HOME/.local/bin" "Local user binaries"
        if [[ "$DISTRO" == "arch" ]]; then
            install_packages "libsecret" "gnome-keyring"
            # Arch has git-credential-libsecret in a different location
            if [[ -f /usr/lib/git-core/git-credential-libsecret ]]; then
                git config --global credential.helper /usr/lib/git-core/git-credential-libsecret
            else
                # Build from source if not available
                if [[ -d /usr/share/git/credential/libsecret ]]; then
                    build_git_credential_helper /usr/share/git/credential/libsecret &&
                        git config --global credential.helper "$HOME/.local/bin/git-credential-libsecret"
                fi
            fi
        else
            # Debian/Ubuntu: need libsecret headers to compile git-credential-libsecret.
            # Prefer brew-provided libsecret (no sudo), fall back to apt packages.
            local libsecret_ready=false

            if is_installed "brew"; then
                if brew install libsecret 2> /dev/null; then
                    libsecret_ready=true
                    # Expose brew's pkg-config path so the build finds libsecret-1.pc
                    local brew_prefix
                    brew_prefix="$(brew --prefix)"
                    export PKG_CONFIG_PATH="${brew_prefix}/lib/pkgconfig:${brew_prefix}/share/pkgconfig:${PKG_CONFIG_PATH:-}"
                fi
            fi

            if [[ "$libsecret_ready" != "true" ]]; then
                if no_admin_mode; then
                    log "NO_ADMIN=true: cannot install libsecret-1-dev headers needed to build git-credential-libsecret." "WARNING"
                    log "Either install libsecret via Linuxbrew (brew install libsecret) and rerun, or configure git credentials manually." "WARNING"
                    return 0
                fi
                install_packages "libsecret-1-0" "libsecret-1-dev" "gnome-keyring"
                libsecret_ready=true
            fi

            local helper_source_dir=""
            local candidate
            local git_prefix=""

            if is_installed "brew" && brew list --versions git &> /dev/null; then
                git_prefix="$(brew --prefix git 2> /dev/null || true)"
            fi

            for candidate in /usr/share/doc/git/contrib/credential/libsecret /usr/share/git/credential/libsecret "$git_prefix/share/git-core/contrib/credential/libsecret" "$git_prefix/share/doc/git/contrib/credential/libsecret"; do
                if [[ -n "$candidate" && -f "$candidate/Makefile" ]]; then
                    helper_source_dir="$candidate"
                    break
                fi
            done

            if [[ -n "$helper_source_dir" ]]; then
                build_git_credential_helper "$helper_source_dir" &&
                    git config --global credential.helper "$HOME/.local/bin/git-credential-libsecret"
            else
                log "Git credential helper source with Makefile was not found in the expected locations." "WARNING"
                log "Skipping git-credential-libsecret setup; configure git credentials manually or install a fuller git package if needed." "WARNING"
            fi
        fi
    else
        log "Skipping Git credential helper setup. macOS uses the built-in keychain."
    fi
}

install_askpass() {
    if [[ "$OS" == "Linux" ]]; then
        if no_admin_mode; then
            log "NO_ADMIN=true: skipping ksshaskpass. This is optional and mostly useful for graphical password prompts." "WARNING"
            return 0
        fi
        log "Installing ksshaskpass..."
        install_packages "ksshaskpass"
    else
        log "Skipping askpass. I don't think MacOS uses this."
    fi
}

# Install prerequisites grouped by category
install_shell_prereqs() {
    log "Installing shell prerequisites..."
    if is_installed "brew"; then
        brew install shellcheck shfmt || log "Error installing shellcheck/shfmt via Homebrew." "WARNING"
    else
        install_packages "shellcheck" "shfmt"
    fi
    if ! is_installed "bash-language-server"; then
        $NODE_CMD install -g bash-language-server || log "Error installing bash-language-server." "WARNING"
    fi
}

install_git_prereqs() {
    log "Installing git prerequisites..."
    if is_installed "brew"; then
        log "Installing git tools via Homebrew..."
        brew bundle --file="$GNU_DIR/brewfiles/Brewfile.git" || log "Error with Brewfile.git" "WARNING"
    fi
}

install_whisper_toolchain() {
    if [[ "$OS" == "Darwin" ]]; then
        # ffmpeg for recording (avfoundation) + whisper.cpp build deps
        install_packages "ffmpeg" "cmake" "pkg-config"
        # Optional convenience tools
        install_packages "sox"
    elif is_installed "brew"; then
        log "Installing Whisper prerequisites via Homebrew/Linuxbrew..."
        brew install ffmpeg cmake pkg-config sox make gcc || log "Error installing Whisper tools via Homebrew." "WARNING"
    elif [[ "$DISTRO" == "arch" ]]; then
        install_packages_translated \
            "ffmpeg" "cmake" "make" "gcc" "sox"
    else
        install_packages_translated \
            "ffmpeg" "cmake" "make" "g++" "sox"
    fi
}

install_whisper_audio_integration() {
    if [[ "$OS" == "Darwin" ]]; then
        log "Audio integration for Whisper uses native macOS devices; no extra system packages needed."
    elif [[ "$DISTRO" == "arch" ]]; then
        # Prefer PipeWire Pulse compatibility on modern Arch installs
        install_packages_translated "alsa-utils" "libasound2-plugins" "pipewire-pulse"
    else
        # Debian/Ubuntu: ensure whisper.el selects PulseAudio input backend by default
        install_packages_translated "alsa-utils" "libasound2-plugins" "pulseaudio" "pulseaudio-utils"
    fi
}

install_whisper_prereqs() {
    log "Installing Whisper (Spacemacs whisper layer) prerequisites..."
    local partial_setup=false

    install_whisper_toolchain

    if [[ "$OS" == "Linux" ]] && no_admin_mode; then
        log "NO_ADMIN=true: skipping distro-level audio backend setup for Whisper." "WARNING"
        log "WSL/desktop audio integration (PulseAudio/PipeWire/ALSA bridging) must already be available." "WARNING"
        partial_setup=true
    else
        install_whisper_audio_integration
    fi

    if [[ "$partial_setup" == "true" ]]; then
        log "Whisper toolchain installed, but audio integration was not configured automatically." "WARNING"
    else
        log "Whisper prerequisites installed successfully." "SUCCESS"
    fi
}

install_yaml_support() {
    log "Installing YAML language server..."
    $NODE_CMD install -g yaml-language-server || log "Error installing yaml-language-server." "WARNING"
}

install_markdown_support() {
    log "Installing markdown support..."

    if ! command -v npm &> /dev/null; then
        log "npm not found; bootstrapping Node.js via nvm for markdown tooling..." "WARNING"
        install_nodejs || log "Failed to bootstrap Node.js automatically for markdown tooling." "WARNING"
    else
        activate_default_node || true
    fi

    # Pandoc for live preview in Spacemacs markdown layer (optional but useful)
    if is_installed "brew"; then
        brew install pandoc || log "Error installing pandoc." "WARNING"
    else
        install_packages "pandoc"
    fi

    # Mermaid CLI for rendering mermaid diagrams in markdown
    log "Installing mermaid-cli for diagram rendering..."
    $NODE_CMD install -g @mermaid-js/mermaid-cli || log "Error installing mermaid-cli." "WARNING"

    # grip for GitHub-flavored markdown preview (installed via requirements.txt)
}

create_snippet_symlink() {
    log "Creating symbolic link for Yasnippet directory..."
    EMACS_SNIPPETS_DIR="$HOME/.emacs.d/private/snippets"
    TARGET_DIR="$GNU_DIR/snippets/"

    mkdir -p "$(dirname "$EMACS_SNIPPETS_DIR")"

    if [ -L "$EMACS_SNIPPETS_DIR" ]; then
        log "A symbolic link already exists at $EMACS_SNIPPETS_DIR. Replacing it."
        rm "$EMACS_SNIPPETS_DIR"
    elif [ -d "$EMACS_SNIPPETS_DIR" ]; then
        log "A directory exists at $EMACS_SNIPPETS_DIR. Backing it up."
        mv "$EMACS_SNIPPETS_DIR" "${EMACS_SNIPPETS_DIR}_backup_$(date +%Y%m%d%H%M%S)"
    else
        log "No existing directory or symlink at $EMACS_SNIPPETS_DIR."
    fi
    ln -s "$TARGET_DIR" "$EMACS_SNIPPETS_DIR"
    log "Symbolic link created successfully from $TARGET_DIR to $EMACS_SNIPPETS_DIR."
}

install_vimscript_lsp() {
    log "Installing Vimscript language server..."
    $NODE_CMD install -g vim-language-server || log "Error installing vim-language-server." "WARNING"
}

texlive_platform() {
    if [[ "$OS" == "Darwin" ]]; then
        echo "universal-darwin"
        return 0
    fi

    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64 | amd64) echo "x86_64-linux" ;;
        aarch64 | arm64) echo "aarch64-linux" ;;
        *) echo "${arch}-linux" ;;
    esac
}

install_texlive_user_local() {
    local TEXLIVE_HOME="$HOME/texlive"
    local CURRENT_YEAR
    CURRENT_YEAR="$(date +%Y)"
    local PLATFORM
    PLATFORM="$(texlive_platform)"
    local TEXDIR="$TEXLIVE_HOME/$CURRENT_YEAR"
    local TEXLIVE_BIN="$TEXDIR/bin/$PLATFORM"
    local TLMGR="$TEXLIVE_BIN/tlmgr"
    local TEXLIVE_PACKAGES=(
        collection-latexrecommended
        latexmk
        amsfonts
        ec
        cm-super
    )

    # Remove old TeX Live years if present
    if [[ -d "$TEXLIVE_HOME" ]]; then
        for old_dir in "$TEXLIVE_HOME"/*/; do
            local dir_name
            dir_name="$(basename "$old_dir")"
            if [[ "$dir_name" =~ ^[0-9]+$ && "$dir_name" != "$CURRENT_YEAR" ]]; then
                log "Removing old TeX Live $dir_name..."
                rm -rf "$old_dir"
            fi
        done
    fi

    if [[ ! -x "$TLMGR" ]]; then
        log "Installing TeX Live $CURRENT_YEAR to $TEXDIR..."
        local INSTALL_TMP
        INSTALL_TMP="$(mktemp -d)"

        curl -L "https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz" \
            -o "$INSTALL_TMP/install-tl.tar.gz" || {
            log "Failed to download TeX Live installer." "ERROR"
            rm -rf "$INSTALL_TMP"
            return 1
        }
        tar -xzf "$INSTALL_TMP/install-tl.tar.gz" -C "$INSTALL_TMP" --strip-components=1

        cat > "$INSTALL_TMP/texlive.profile" << TEXPROFILE
selected_scheme scheme-basic
TEXDIR $TEXDIR
TEXMFLOCAL $TEXDIR/texmf-local
TEXMFSYSCONFIG $TEXDIR/texmf-config
TEXMFSYSVAR $TEXDIR/texmf-var
TEXMFHOME ~/texmf
TEXMFCONFIG ~/.texlive${CURRENT_YEAR}/texmf-config
TEXMFVAR ~/.texlive${CURRENT_YEAR}/texmf-var
instopt_adjustpath 0
instopt_adjustrepo 1
instopt_letter 0
tlpdbopt_autobackup 1
tlpdbopt_install_docfiles 0
tlpdbopt_install_srcfiles 0
TEXPROFILE
        echo "binary_${PLATFORM} 1" >> "$INSTALL_TMP/texlive.profile"

        "$INSTALL_TMP"/install-tl -profile "$INSTALL_TMP/texlive.profile" || {
            log "TeX Live installation failed." "ERROR"
            rm -rf "$INSTALL_TMP"
            return 1
        }
        rm -rf "$INSTALL_TMP"
        log "TeX Live $CURRENT_YEAR installed successfully." "SUCCESS"
    fi

    export PATH="$TEXLIVE_BIN:$PATH"
    add_to_path "$TEXLIVE_BIN" "TeX Live $CURRENT_YEAR"

    "$TLMGR" update --self || log "tlmgr update --self failed." "WARNING"
    log "Installing a slim default LaTeX package set via tlmgr..."
    "$TLMGR" install "${TEXLIVE_PACKAGES[@]}" || {
        log "Some optional LaTeX packages failed to install from the slim default set." "WARNING"
    }
}

install_latex_tooling() {
    if [[ "$OS" == "Darwin" ]]; then
        # Use Brewfile for texlab, poppler, aspell
        if is_installed "brew"; then
            log "Installing LaTeX tools via Homebrew..."
            brew bundle --file="$GNU_DIR/brewfiles/Brewfile.latex" || log "Error with Brewfile.latex" "WARNING"
        fi
    elif is_installed "brew"; then
        log "Installing LaTeX tools via Homebrew/Linuxbrew..."
        brew bundle --file="$GNU_DIR/brewfiles/Brewfile.latex" || log "Error with Brewfile.latex" "WARNING"
    elif [[ "$DISTRO" == "arch" ]]; then
        # Arch: texlab is in official repos
        log "Installing LaTeX tooling for Arch..."
        install_packages "okular" "aspell" "texlab"
    else
        # Debian/Ubuntu: user-space texlab, plus optional system viewers/spell tools
        if no_admin_mode; then
            log "NO_ADMIN=true: skipping okular and aspell (system packages). texlab will still be installed to user space." "WARNING"
        else
            install_packages "okular" "aspell"
        fi

        # Install texlab from pre-built binary (not available in apt)
        if ! is_installed "texlab"; then
            log "Installing texlab from GitHub releases..."
            local texlab_arch
            case "$(uname -m)" in
                x86_64 | amd64) texlab_arch="x86_64" ;;
                aarch64 | arm64) texlab_arch="aarch64" ;;
                *)
                    log "Unsupported architecture $(uname -m) for texlab binary download." "ERROR"
                    return 1
                    ;;
            esac
            local texlab_os
            if [[ "$OS" == "Darwin" ]]; then
                texlab_os="macos"
            else
                texlab_os="linux"
            fi

            TEXLAB_VERSION=$(curl -s https://api.github.com/repos/latex-lsp/texlab/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
            TEXLAB_URL="https://github.com/latex-lsp/texlab/releases/download/v${TEXLAB_VERSION}/texlab-${texlab_arch}-${texlab_os}.tar.gz"

            curl -L "$TEXLAB_URL" -o /tmp/texlab.tar.gz || {
                log "Failed to download texlab." "ERROR"
                return 1
            }
            tar -xzf /tmp/texlab.tar.gz -C /tmp || {
                log "Failed to extract texlab." "ERROR"
                return 1
            }
            mkdir -p "$HOME/.local/bin"
            mv /tmp/texlab "$HOME/.local/bin/" || {
                log "Failed to move texlab to ~/.local/bin." "ERROR"
                return 1
            }
            chmod +x "$HOME/.local/bin/texlab"
            rm /tmp/texlab.tar.gz
            log "texlab installed to ~/.local/bin successfully." "SUCCESS"
        else
            log "texlab is already installed."
        fi
    fi
}

install_latex_distribution() {
    if [[ "$OS" == "Darwin" ]]; then
        install_texlive_user_local
    elif [[ "$OS" == "Linux" ]] && no_admin_mode; then
        log "NO_ADMIN=true: installing user-local TeX Live instead of distro packages."
        install_texlive_user_local
    elif [[ "$DISTRO" == "arch" ]]; then
        install_packages "texlive-latexextra"
    else
        install_packages "texlive-latex-extra"
    fi
}

install_latex_tools() {
    log "Installing LaTeX tools..."
    install_latex_tooling
    install_latex_distribution

    if [[ "$OS" == "Linux" ]] && is_installed "brew"; then
        log "Note: Homebrew/Linuxbrew covers editor/tooling support; TeX distribution support is handled separately." "WARNING"
    fi
}

install_python_prereqs() {
    log "Installing Python tools..."
    if [[ "$OS" == "Linux" ]] && no_admin_mode; then
        ensure_uv_installed || return 1
        uv python install 3.12 || log "uv could not preinstall Python 3.12; continuing with automatic Python downloads." "WARNING"

        local requirements_file="$GNU_DIR/requirements.txt"
        if [[ -f "$requirements_file" ]]; then
            log "Installing Python tools from requirements.txt via uv..."
            while IFS= read -r package || [ -n "$package" ]; do
                [[ -z "$package" || "$package" =~ ^# ]] && continue
                local pkg_name
                pkg_name=$(echo "$package" | sed 's/\[.*\]//g' | sed 's/[><=!].*//g' | xargs)
                log "Installing $pkg_name via uv..."
                uv tool install --force "$package" || log "Error installing $pkg_name via uv." "WARNING"
            done < "$requirements_file"
        else
            log "requirements.txt not found. Using fallback Python tool list with uv..." "WARNING"
            local python_packages=("pyright" "debugpy" "autoflake" "flake8" "isort" "jupytext")
            local pkg
            for pkg in "${python_packages[@]}"; do
                log "Installing $pkg via uv..."
                uv tool install --force "$pkg" || log "Error installing $pkg via uv." "WARNING"
            done
        fi
        add_to_path "$HOME/.local/bin" "Python/uv tools"
        log "Python tools installed in user space via uv." "SUCCESS"
        return 0
    fi

    if [[ "$OS" == "Darwin" ]]; then
        # macOS: pip comes with python3, ipython is handled by install_python_env
        install_packages "python3" "pipx"
    elif [[ "$DISTRO" == "arch" ]]; then
        # Arch: python-pip is the package name
        install_packages "python" "python-pip" "python-pipx"
    else
        # Debian/Ubuntu: needs python3-pip separately
        install_packages "python3" "python3-pip" "pipx"
    fi

    local requirements_file="$GNU_DIR/requirements.txt"

    if [[ -f "$requirements_file" ]]; then
        log "Installing Python packages from requirements.txt..."

        while IFS= read -r package || [ -n "$package" ]; do
            # Skip empty lines and comments
            [[ -z "$package" || "$package" =~ ^# ]] && continue

            # Extract package name (before [extras] or version specifiers)
            pkg_name=$(echo "$package" | sed 's/\[.*\]//g' | sed 's/[><=!].*//g' | xargs)

            log "Installing $pkg_name..."
            $PIP_CMD "$package" || log "Error installing $pkg_name." "WARNING"
        done < "$requirements_file"

        log "Python packages installed successfully." "SUCCESS"
    else
        log "requirements.txt not found. Using fallback installation..." "WARNING"
        # Fallback to hardcoded installation
        python_packages=("pyright" "debugpy" "autoflake" "flake8" "isort" "jupytext")
        for pkg in "${python_packages[@]}"; do
            log "Installing $pkg via pip..."
            $PIP_CMD "$pkg" || log "Error installing Python package $pkg." "WARNING"
        done
    fi

    # Add Python bin directory to PATH
    PYTHON_BIN_DIR="$(python3 -m site --user-base)/bin"
    add_to_path "$PYTHON_BIN_DIR" "Python binaries (pipx)"

    # Jupyter CLI tooling via uv (matches setup-dev-tools.ps1 behavior on Windows).
    if command -v uv > /dev/null 2>&1; then
        for tool in jupytext ipython; do
            if ! uv tool list 2> /dev/null | grep -q "^${tool}\b"; then
                log "Installing ${tool} via uv tool install..." "INFO"
                uv tool install "${tool}"
            fi
        done
        if ! uv tool list 2> /dev/null | grep -q "^ipykernel\b"; then
            log "Installing ipykernel via uv tool install..." "INFO"
            uv tool install ipykernel --with ipython
        fi
    else
        log "WARNING: uv not found; skipping Jupyter CLI install. Run bootstrap.sh first." "WARNING"
    fi
}

install_r_support() {
    log "Installing R tools for ESS..."
    local r_available=false

    if [[ "$OS" == "Linux" ]] && is_installed "brew"; then
        log "Installing R via Homebrew/Linuxbrew..."
        brew install r || log "Error installing R via Homebrew." "WARNING"
    elif [[ "$OS" == "Linux" ]] && no_admin_mode; then
        log "NO_ADMIN=true and Homebrew is not available: skipping system R installation." "WARNING"
        log "Install Linuxbrew R first, then rerun this target to configure languageserver in your user library." "WARNING"
    elif [[ "$OS" == "Darwin" ]]; then
        install_packages "r"
    elif [[ "$DISTRO" == "arch" ]]; then
        # Arch: r package includes development files
        install_packages "r" "curl" "openssl" "libxml2"
    else
        # Debian/Ubuntu
        install_packages "r-base" "r-base-dev" "libcurl4-openssl-dev" "libssl-dev" "libxml2-dev"
    fi

    if is_installed "Rscript"; then
        r_available=true
        log "Ensuring the R languageserver package is installed..."
        # Create user library directory if it doesn't exist
        Rscript -e 'dir.create(Sys.getenv("R_LIBS_USER"), showWarnings = FALSE, recursive = TRUE)'
        # Install to user library to avoid permission issues
        Rscript -e 'if (!requireNamespace("languageserver", quietly = TRUE)) install.packages("languageserver", repos = "https://cloud.r-project.org", lib = Sys.getenv("R_LIBS_USER"))' ||
            log "Failed to install languageserver package for R." "WARNING"
    else
        log "Rscript not found on PATH; skipping languageserver install." "WARNING"
    fi

    if [[ "$r_available" == "true" ]]; then
        log "R support installed/configured successfully." "SUCCESS"
    elif [[ "$OS" == "Linux" ]] && no_admin_mode; then
        log "R support partially configured: user-library setup was skipped because no usable R installation is available in user space yet." "WARNING"
    fi
}

install_c_cpp_prereqs() {
    log "Installing C/C++ prerequisites..."
    if is_installed "brew"; then
        log "Installing C/C++ tools via Homebrew..."
        brew bundle --file="$GNU_DIR/brewfiles/Brewfile.c_cpp" || log "Error with Brewfile.c_cpp" "WARNING"

        # Add LLVM to PATH for clangd, clang-format, etc.
        local LLVM_BIN_DIR
        LLVM_BIN_DIR="$(brew --prefix llvm)/bin"
        if [[ -d "$LLVM_BIN_DIR" ]]; then
            export PATH="$LLVM_BIN_DIR:$PATH"
            add_to_path "$LLVM_BIN_DIR" "LLVM/Clang (C++ toolchain)"
        fi
    else
        # Fallback for systems without brew
        install_packages "llvm"
    fi
    log "C/C++ prerequisites installed successfully." "SUCCESS"
}

install_sql_tools() {
    log "Installing SQL tools..."

    local GO_BIN_DIR="$HOME/go/bin"

    # Install Go (required for sqls)
    if is_installed "brew"; then
        log "Installing Go via Homebrew..."
        brew bundle --file="$GNU_DIR/brewfiles/Brewfile.sql" || log "Error with Brewfile.sql" "WARNING"
    else
        # Fallback if brew is not available
        install_packages "golang-go"
    fi

    # Ensure Go bin is in PATH for current session
    export PATH="$GO_BIN_DIR:$PATH"

    # Install sqls language server
    if ! is_installed "sqls"; then
        log "Installing sqls language server via go install..."
        go install github.com/sqls-server/sqls@latest || log "Error installing sqls via go." "WARNING"
    else
        log "sqls is already installed. Skipping."
    fi

    # Configure PATH for Go binaries
    add_to_path "$GO_BIN_DIR" "Go binaries (sqls)"

    log "SQL tools setup complete!" "SUCCESS"
}

install_js_tools() {
    log "Installing JavaScript tools..."

    # Install nvm, bun, pnpm via Homebrew
    if is_installed "brew"; then
        log "Installing JavaScript tools via Homebrew..."
        brew bundle --file="$GNU_DIR/brewfiles/Brewfile.javascript" || log "Error with Brewfile.javascript" "WARNING"
    else
        log "Homebrew not found. Please install Homebrew first." "WARNING"
    fi

    # JavaScript language servers and tools (always install latest)
    local js_packages=(
        "import-js"
        "typescript"
        "typescript-language-server"
        "prettier"
        "eslint"
        "vscode-langservers-extracted"
    )

    for pkg in "${js_packages[@]}"; do
        log "Installing $pkg via npm..."
        $NODE_CMD install -g "$pkg" || log "Error installing $pkg." "WARNING"
    done

    # JS DAP setup (vscode-js-debug)
    log "Setting up JavaScript DAP (vscode-js-debug)..."
    if ! [ -d "$HOME/.emacs.d/.extension/vscode-js-debug" ]; then
        log "JavaScript DAP will be automatically installed via dap-node-setup in Spacemacs."
        log "You can also manually run 'M-x dap-node-setup' within Emacs."
    fi

    log "JavaScript tools installed successfully." "SUCCESS"
}

install_html_css_support() {
    log "HTML and CSS language servers are handled by vscode-langservers-extracted in the JS layer."
}

install_docker_support() {
    log "Installing Docker and tools..."
    if is_installed "brew"; then
        log "Installing Docker tools via Homebrew..."
        brew bundle --file="$GNU_DIR/brewfiles/Brewfile.docker" || log "Error with Brewfile.docker" "WARNING"
    else
        # Fallback for systems without brew
        install_packages "docker"
    fi
    $NODE_CMD install -g dockerfile-language-server-nodejs || log "Error installing dockerfile-language-server." "WARNING"
}

install_kubernetes_support() {
    log "Installing Kubernetes tools..."
    if is_installed "brew"; then
        log "Installing Kubernetes tools via Homebrew..."
        brew bundle --file="$GNU_DIR/brewfiles/Brewfile.kubernetes" || log "Error with Brewfile.kubernetes" "WARNING"
    else
        # Fallback for systems without brew
        install_packages "kubectl"
        log "ArgoCD CLI requires Homebrew or manual install on non-brew systems." "WARNING"
    fi
    log "Kubernetes tools installed successfully." "SUCCESS"
}

install_ocaml_support() {
    log "Installing OCaml and opam..."
    # Ensure base tools are present
    if is_installed "brew"; then
        log "Installing OCaml tools via Homebrew..."
        brew bundle --file="$GNU_DIR/brewfiles/Brewfile.ocaml" || log "Error with Brewfile.ocaml" "WARNING"
    else
        # Fallback for systems without brew
        install_packages "ocaml" "opam"
    fi

    # Initialize opam if needed
    if ! opam var root &> /dev/null; then
        log "Initializing opam..."
        # TODO: Evaluate sandboxing needs for your environment
        opam init --disable-sandboxing -a || log "Error initializing opam." "WARNING"
    fi

    # Load opam env into current shell
    eval "$(opam env)" || true

    # Persist opam env to user shell RC
    add_to_shell_rc 'eval "$(opam env)"' "opam"

    # Update opam repositories and upgrade installed packages
    opam update && opam upgrade -y || log "opam update/upgrade encountered issues." "WARNING"

    # Install all OCaml tools in one command for optimal dependency resolution
    # Order matters: ocp-indent first (pulls cmdliner) to avoid recompilation cascade
    log "Installing OCaml development tools via opam..."
    opam install -y ocp-indent merlin ocaml-lsp-server utop ocamlformat ||
        log "Some opam packages failed to install." "WARNING"
    log "OCaml support installed successfully." "SUCCESS"
}

install_terraform_support() {
    log "Installing Terraform..."

    if [[ "$DISTRO" == "arch" ]]; then
        # Arch: terraform is in official repos, terraform-ls is in AUR
        log "Installing Terraform for Arch..."
        install_packages "terraform" "ansible" "jq"
        install_aur_packages "terraform-ls"

        # Cloud provider CLIs via Brewfile (Linuxbrew)
        if is_installed "brew"; then
            if [[ -f "$GNU_DIR/brewfiles/Brewfile.terraform" ]]; then
                log "Installing cloud provider CLIs via Linuxbrew..."
                brew bundle --file="$GNU_DIR/brewfiles/Brewfile.terraform" || log "Error with Brewfile.terraform" "WARNING"
            fi
        fi

    elif [[ $OS == "Linux" ]]; then
        # Debian/Ubuntu: prefer Homebrew (no sudo needed) over HashiCorp apt repo
        if is_installed "brew"; then
            log "Installing Terraform tools via Linuxbrew (no sudo required)..."
            brew tap hashicorp/tap || log "Error adding hashicorp/tap." "WARNING"
            brew install hashicorp/tap/terraform || log "Error installing terraform." "WARNING"
            brew install hashicorp/tap/terraform-ls || log "Error installing terraform-ls." "WARNING"

            # ansible and jq via brew
            brew install ansible jq || log "Error installing ansible/jq." "WARNING"

            # Cloud provider CLIs via Brewfile
            if [[ -f "$GNU_DIR/brewfiles/Brewfile.terraform" ]]; then
                log "Installing cloud provider CLIs via Linuxbrew..."
                brew bundle --file="$GNU_DIR/brewfiles/Brewfile.terraform" || log "Error with Brewfile.terraform" "WARNING"
            fi
        else
            # Fallback: HashiCorp apt repo (requires sudo)
            if [[ "$NO_ADMIN" == "true" ]]; then
                log "NO_ADMIN=true: skipping Terraform apt-repo fallback because it requires system changes." "WARNING"
                return 0
            fi
            log "Homebrew not found, falling back to HashiCorp apt repo (requires sudo)..." "WARNING"
            if [[ ! -f /usr/share/keyrings/hashicorp-archive-keyring.gpg ]]; then
                log "Adding HashiCorp GPG key..."
                wget -qO- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
            fi
            DISTRO_CODENAME=$(grep -oP '(?<=VERSION_CODENAME=).+' /etc/os-release || echo "bookworm")
            if ! grep -q "https://apt.releases.hashicorp.com" /etc/apt/sources.list.d/hashicorp.list 2> /dev/null; then
                log "Adding HashiCorp apt repository for $DISTRO_CODENAME..."
                echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $DISTRO_CODENAME main" |
                    sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
            fi

            sudo apt update -qq
            install_packages "terraform" "terraform-ls" "ansible" "jq"
        fi

    elif [[ $OS == "Darwin" ]]; then
        log "Adding HashiCorp tap to Homebrew..."
        brew tap hashicorp/tap || log "Error adding hashicorp/tap." "WARNING"

        install_packages "terraform" "terraform-ls" "ansible" "jq"

        # Cloud provider CLIs via Brewfile
        if [[ -f "$GNU_DIR/brewfiles/Brewfile.terraform" ]]; then
            log "Installing cloud provider CLIs..."
            brew bundle --file="$GNU_DIR/brewfiles/Brewfile.terraform" || log "Error with Brewfile.terraform" "WARNING"
        fi
    fi
}

install_rust_support() {
    log "Installing Rust development tools..."

    local CARGO_BIN_DIR="$HOME/.cargo/bin"

    # Install rustup (Rust toolchain manager)
    if ! is_installed "rustup"; then
        log "Installing rustup (Rust toolchain manager)..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable

        # Source cargo environment for current session
        # shellcheck disable=SC1091
        [ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

        log "rustup installed successfully." "SUCCESS"
    else
        log "rustup is already installed."
    fi

    # Ensure cargo is in PATH for current session
    export PATH="$CARGO_BIN_DIR:$PATH"

    # Install stable Rust toolchain
    if is_installed "rustup"; then
        log "Installing Rust stable toolchain..."
        rustup install stable
        rustup default stable
        log "Rust stable toolchain installed." "SUCCESS"

        # Install essential Rust components
        log "Installing rust-analyzer LSP server..."
        rustup component add rust-analyzer

        log "Installing rustfmt formatter..."
        rustup component add rustfmt

        log "Installing clippy linter..."
        rustup component add clippy

        log "Rust components installed successfully." "SUCCESS"
    else
        log "rustup not found. Cannot install Rust components." "ERROR"
        return 1
    fi

    # Ensure cargo is available
    if ! is_installed "cargo"; then
        log "Cargo not found after rustup installation. Please restart your shell." "WARNING"
        return 1
    fi

    # Install cargo extensions
    log "Installing cargo-edit (add/remove dependencies)..."
    cargo install cargo-edit || log "Failed to install cargo-edit." "WARNING"

    log "Installing cargo-outdated (check for outdated dependencies)..."
    cargo install cargo-outdated || log "Failed to install cargo-outdated." "WARNING"

    # Install debugger support
    if [[ "$OS" == "Darwin" ]]; then
        log "LLDB debugger is available via Xcode Command Line Tools (already installed)."
    else
        log "Installing LLDB debugger for DAP support..."
        install_packages "lldb"
    fi

    # Configure PATH for cargo binaries
    add_to_path "$CARGO_BIN_DIR" "Rust cargo binaries"

    log "Rust development environment setup complete!" "SUCCESS"
}

install_starship() {
    log "Setting up Starship prompt..."

    local shell_rc
    local shell_name
    shell_rc="$(get_shell_rc)"
    shell_name="$(get_shell_name)"

    # Install starship binary
    if ! is_installed "starship"; then
        if is_installed "brew"; then
            brew install starship || log "Error installing starship via brew." "WARNING"
        elif [[ "$DISTRO" == "arch" ]]; then
            install_packages "starship"
        else
            local starship_bin_dir="/usr/local/bin"
            if [[ "$OS" == "Linux" ]] && no_admin_mode; then
                starship_bin_dir="$HOME/.local/bin"
                mkdir -p "$starship_bin_dir"
                log "NO_ADMIN=true: installing starship to $starship_bin_dir"
            else
                log "Installing starship via official installer..."
            fi

            curl -sS https://starship.rs/install.sh | sh -s -- -b "$starship_bin_dir" -y || {
                log "Failed to install starship." "ERROR"
                return 1
            }
        fi
    else
        log "starship is already installed."
    fi

    # Symlink starship config from repo
    log "Setting up Starship config..."
    mkdir -p "$HOME/.config"
    if [ -f "$HOME/.config/starship.toml" ] && [ ! -L "$HOME/.config/starship.toml" ]; then
        log "Existing starship.toml found. Backing up..."
        mv "$HOME/.config/starship.toml" "$HOME/.config/starship.toml.bak.$(date +%Y%m%d%H%M%S)"
    fi
    ln -sf "$GNU_DIR/starship.toml" "$HOME/.config/starship.toml"
    log "Symlinked Starship config."

    # Add starship init to shell RC (should be near end of file)
    if is_installed "starship"; then
        if ! grep -q 'eval "$(starship init' "$shell_rc" 2> /dev/null; then
            log "Adding Starship initialization to $shell_rc..."
            echo "" >> "$shell_rc"
            echo "# Starship prompt" >> "$shell_rc"
            echo "eval \"\$(starship init $shell_name)\"" >> "$shell_rc"
            log "Starship initialization added to $shell_rc." "SUCCESS"
        else
            log "Starship initialization already present in $shell_rc."
        fi
    fi

    log "Starship prompt setup complete!" "SUCCESS"
}

install_syntax_highlighting() {
    log "Installing shell syntax highlighting..."

    local shell_name
    local partial_setup=false
    shell_name="$(get_shell_name)"

    if [[ "$shell_name" == "zsh" ]]; then
        log "Detected zsh - installing zsh plugins..."

        # zsh-vi-mode: enhanced vi mode (cursor shapes, text objects, surround)
        if is_installed "brew"; then
            brew install zsh-vi-mode || log "Error installing zsh-vi-mode via brew." "WARNING"
        elif [[ "$DISTRO" == "arch" ]]; then
            install_aur_packages "zsh-vi-mode" || _install_zsh_vi_mode_from_source
        else
            _install_zsh_vi_mode_from_source
        fi

        # zsh-autosuggestions + zsh-syntax-highlighting
        if is_installed "brew"; then
            brew install zsh-autosuggestions || log "Error installing zsh-autosuggestions via brew." "WARNING"
            brew install zsh-syntax-highlighting || log "Error installing zsh-syntax-highlighting via brew." "WARNING"
        elif [[ "$DISTRO" == "arch" ]]; then
            install_packages "zsh-autosuggestions" "zsh-syntax-highlighting"
        else
            install_packages "zsh-autosuggestions" "zsh-syntax-highlighting"
        fi
    else
        log "Detected bash - installing blesh (Bash Line Editor)..."
        if [[ "$DISTRO" == "arch" ]]; then
            if ! install_aur_packages "blesh-git"; then
                log "AUR install failed, falling back to git clone..." "WARNING"
                if ! _install_blesh_from_source; then
                    partial_setup=true
                fi
            fi
        else
            if ! _install_blesh_from_source; then
                partial_setup=true
            fi
        fi

        # Symlink blesh config (.blerc) for keybinding and cursor overrides
        if [[ -f "$GNU_DIR/.blerc" ]]; then
            ln -sf "$GNU_DIR/.blerc" "$HOME/.blerc"
            log "Symlinked blesh config (.blerc)."
        fi
    fi

    if [[ "$partial_setup" == "true" ]]; then
        log "Shell syntax highlighting partially configured: bash line editing support was not fully installed." "WARNING"
    else
        log "Shell syntax highlighting setup complete!" "SUCCESS"
    fi
}

# Helper: build blesh from source into ~/.local
_install_blesh_from_source() {
    local blesh_dir="${HOME}/.local/share/blesh"

    if [[ -f "$blesh_dir/ble.sh" ]]; then
        log "blesh is already installed at $blesh_dir/ble.sh"
        return 0
    fi

    # gawk is required for the build
    if ! is_installed "gawk"; then
        log "Installing gawk (required for blesh build)..."
        install_packages "gawk"
        if ! is_installed "gawk" && is_installed "brew"; then
            log "Trying gawk via Homebrew/Linuxbrew..."
            brew install gawk || log "brew install gawk failed." "WARNING"
        fi
        if ! is_installed "gawk"; then
            if no_admin_mode; then
                log "NO_ADMIN=true: unable to install gawk automatically, so blesh will be skipped." "WARNING"
            else
                log "gawk is still unavailable after attempted install; cannot build blesh." "ERROR"
            fi
            return 1
        fi
    fi

    log "Cloning and building blesh..."
    local tmp_dir
    tmp_dir=$(mktemp -d)
    git clone --recursive --depth 1 https://github.com/akinomyoga/ble.sh.git "$tmp_dir/ble.sh" || {
        log "Failed to clone blesh." "ERROR"
        rm -rf "$tmp_dir"
        return 1
    }

    make -C "$tmp_dir/ble.sh" install PREFIX="$HOME/.local" || {
        log "Failed to build/install blesh." "ERROR"
        rm -rf "$tmp_dir"
        return 1
    }

    rm -rf "$tmp_dir"
    log "blesh installed to $blesh_dir" "SUCCESS"
}

# Helper: clone zsh-vi-mode into ~/.local/share for Debian/Ubuntu
_install_zsh_vi_mode_from_source() {
    local zvm_dir="${HOME}/.local/share/zsh-vi-mode"

    if [[ -f "$zvm_dir/zsh-vi-mode.plugin.zsh" ]]; then
        log "zsh-vi-mode is already installed at $zvm_dir"
        return 0
    fi

    log "Cloning zsh-vi-mode..."
    git clone --depth 1 https://github.com/jeffreytse/zsh-vi-mode.git "$zvm_dir" || {
        log "Failed to clone zsh-vi-mode." "ERROR"
        return 1
    }

    log "zsh-vi-mode installed to $zvm_dir" "SUCCESS"
}

install_cli_tools_core() {
    log "Installing core CLI tools..."

    if [[ "$OS" == "Darwin" ]]; then
        install_packages "htop" "gpg" "cloc"

        if is_installed "brew"; then
            log "Installing CLI core via Homebrew..."
            brew bundle --file="$GNU_DIR/brewfiles/Brewfile.cli_tools" || log "Error with Brewfile.cli_tools" "WARNING"
        fi

        if ! xcode-select -p &> /dev/null; then
            log "Xcode Command Line Tools not found. Installing..."
            xcode-select --install || log "Error installing Xcode Command Line Tools." "WARNING"
        else
            log "Xcode Command Line Tools are already installed."
        fi
    elif [[ "$DISTRO" == "arch" ]]; then
        if is_installed "brew"; then
            log "Installing CLI core via Homebrew/Linuxbrew..."
            brew install htop gnupg cloc cmake || log "Error installing base CLI tools via Homebrew." "WARNING"
            brew bundle --file="$GNU_DIR/brewfiles/Brewfile.cli_tools" || log "Error with Brewfile.cli_tools" "WARNING"
        else
            log "Homebrew not found; falling back to distro packages for CLI core tools..."
            install_packages "htop" "gnupg" "cloc" "cmake"
            install_packages "eza" "bat" "ripgrep" "fd" "fzf" "zoxide" "lazygit" "tmux" "starship"
        fi
    else
        if is_installed "brew"; then
            log "Installing CLI core via Homebrew/Linuxbrew..."
            brew install htop gnupg cloc cmake || log "Error installing base CLI tools via Homebrew." "WARNING"
            brew bundle --file="$GNU_DIR/brewfiles/Brewfile.cli_tools" || log "Error with Brewfile.cli_tools" "WARNING"
        else
            log "Homebrew not found; falling back to distro packages for available CLI core tools..."
            install_packages "htop" "gpg" "cloc" "cmake" "tmux" "fzf" "ripgrep" "zoxide"
        fi
    fi
}

install_cli_tools_system() {
    log "Installing CLI system-integration extras..."

    if [[ "$OS" == "Darwin" ]]; then
        log "No separate CLI system extras needed on macOS."
    elif [[ "$DISTRO" == "arch" ]]; then
        install_packages "cups" "xclip" "libtool"
    else
        install_packages "cups" "cups-client" "lpr" "xclip" "libtool-bin"
    fi
}

install_cli_tools() {
    log "Installing general CLI tools..."

    # git is assumed to exist (used throughout, e.g. cloning oh-my-tmux).
    # If it's missing, fail early with a clear message instead of dying mid-run.
    if ! command -v git &> /dev/null; then
        log "git is required but not found in PATH. Install git first (company-approved method), then re-run." "ERROR"
        return 1
    fi

    # Get shell RC file and shell name for use throughout function
    local shell_rc
    local shell_name
    shell_rc="$(get_shell_rc)"
    shell_name="$(get_shell_name)"

    install_cli_tools_core

    if [[ "$OS" == "Linux" ]] && no_admin_mode; then
        log "NO_ADMIN=true: skipping CLI system-integration extras (printing, clipboard, libtool)." "WARNING"
        log "CLI core tools installed, but optional system extras were not configured." "WARNING"
    else
        install_cli_tools_system
    fi

    # Install oh-my-tmux (gpakosz/.tmux)
    log "Setting up oh-my-tmux..."
    if [[ ! -d "$HOME/.tmux" ]]; then
        log "Cloning oh-my-tmux..."
        git clone https://github.com/gpakosz/.tmux.git "$HOME/.tmux" || log "Error cloning oh-my-tmux." "WARNING"
    else
        log "oh-my-tmux already installed, updating..."
        git -C "$HOME/.tmux" pull || log "Error updating oh-my-tmux." "WARNING"
    fi

    # Create tmux config symlinks
    if [[ -d "$HOME/.tmux" ]]; then
        ln -sf "$HOME/.tmux/.tmux.conf" "$HOME/.tmux.conf"
        ln -sf "$GNU_DIR/.tmux.conf.local" "$HOME/.tmux.conf.local"
        log "oh-my-tmux configured with vi keybindings and Powerline symbols."
    fi

    # Configure Ghostty terminal
    log "Setting up Ghostty config..."
    mkdir -p "$HOME/.config/ghostty"
    if [ ! -L "$HOME/.config/ghostty/config" ]; then
        ln -sf "$GNU_DIR/ghostty/config" "$HOME/.config/ghostty/config"
        log "Created symlink for Ghostty config."
    else
        log "Ghostty config symlink already exists."
    fi

    # Configure SSH for Ghostty compatibility
    # Ghostty uses xterm-ghostty terminfo which isn't on most remote servers
    # Setting TERM=xterm-256color ensures compatibility when SSHing
    if [ -f "$HOME/.ssh/config" ]; then
        if ! grep -q 'SetEnv TERM=xterm-256color' "$HOME/.ssh/config"; then
            log "Adding TERM override to SSH config for Ghostty compatibility..."
            # Prepend to ensure it applies to all hosts
            temp_ssh=$(mktemp)
            echo "Host *" > "$temp_ssh"
            echo "    SetEnv TERM=xterm-256color" >> "$temp_ssh"
            echo "" >> "$temp_ssh"
            cat "$HOME/.ssh/config" >> "$temp_ssh"
            mv "$temp_ssh" "$HOME/.ssh/config"
            chmod 600 "$HOME/.ssh/config"
            log "SSH config updated for Ghostty compatibility."
        else
            log "SSH config already has TERM override."
        fi
    else
        log "Creating SSH config with Ghostty TERM override..."
        mkdir -p "$HOME/.ssh"
        echo "Host *" > "$HOME/.ssh/config"
        echo "    SetEnv TERM=xterm-256color" >> "$HOME/.ssh/config"
        chmod 600 "$HOME/.ssh/config"
        log "SSH config created with Ghostty compatibility."
    fi

    # Configure shell aliases symlink (sourcing added at very end of function)
    log "Setting up shell aliases..."
    if [ ! -L "$HOME/.shell_aliases" ]; then
        ln -sf "$GNU_DIR/.shell_aliases" "$HOME/.shell_aliases"
        log "Created symlink for .shell_aliases"
    else
        log ".shell_aliases symlink already exists."
    fi

    # Configure zoxide in shell RC (must be at the end)
    if is_installed "zoxide"; then

        if ! grep -q 'eval "$(zoxide init' "$shell_rc" 2> /dev/null; then
            log "Adding zoxide initialization to $shell_rc..."
            echo "" >> "$shell_rc"
            echo "# zoxide - smart cd (must be at the end)" >> "$shell_rc"
            echo "eval \"\$(zoxide init $shell_name)\"" >> "$shell_rc"
            log "zoxide initialization added to $shell_rc." "SUCCESS"
        else
            log "zoxide initialization already present in $shell_rc."
        fi
    fi

    # Configure vi mode for bash only (zsh vi mode is handled by
    # zsh-vi-mode plugin + zvm_after_init hook in .shell_aliases)
    if [[ "$shell_name" == "bash" ]]; then
        if ! grep -q '# Vi mode' "$shell_rc" 2> /dev/null; then
            log "Adding vi mode configuration to $shell_rc..."
            echo "" >> "$shell_rc"
            echo "# Vi mode for command line editing" >> "$shell_rc"
            cat >> "$shell_rc" << 'EOF'
set -o vi
bind '"jk":vi-movement-mode'
bind 'set keyseq-timeout 200'  # 200ms timeout for key sequences (matches vim/spacemacs)
EOF
            log "Vi mode configuration added to $shell_rc." "SUCCESS"
        else
            log "Vi mode configuration already present in $shell_rc."
        fi
    fi

    # Set up Starship prompt
    install_starship

    # Set up shell syntax highlighting
    install_syntax_highlighting

    # Source shell aliases LAST — blesh attaches at end of .shell_aliases,
    # so this must come after starship, zoxide, vi mode, etc.
    if ! grep -q 'source.*\.shell_aliases' "$shell_rc" 2> /dev/null; then
        log "Adding .shell_aliases sourcing to $shell_rc..."
        echo "" >> "$shell_rc"
        echo "# Load custom shell aliases (MUST be last — ble.sh attaches here)" >> "$shell_rc"
        echo "if [ -f ~/.shell_aliases ]; then" >> "$shell_rc"
        echo "    source ~/.shell_aliases" >> "$shell_rc"
        echo "fi" >> "$shell_rc"
        log "Shell aliases sourcing added to $shell_rc." "SUCCESS"
    elif ! tail -n 5 "$shell_rc" | grep -q 'source.*\.shell_aliases'; then
        log ".shell_aliases sourcing found but not at end of $shell_rc, relocating..."
        # Remove existing sourcing block and trailing blank lines (portable, no sed -i)
        if grep -v '# Load custom shell aliases\|# Source shell aliases' "$shell_rc" |
            awk '/if \[ -f ~\/.shell_aliases \]/{skip=1} skip && /^fi$/{skip=0; next} !skip' |
            awk 'NF{found=1} found' |
            tac | awk 'NF{found=1} found' | tac \
            > "${shell_rc}.tmp"; then
            mv "${shell_rc}.tmp" "$shell_rc"
        else
            rm -f "${shell_rc}.tmp"
            log "Failed to relocate .shell_aliases sourcing in $shell_rc." "ERROR"
            return 1
        fi
        # Re-add at end
        echo "" >> "$shell_rc"
        echo "# Load custom shell aliases (MUST be last — ble.sh attaches here)" >> "$shell_rc"
        echo "if [ -f ~/.shell_aliases ]; then" >> "$shell_rc"
        echo "    source ~/.shell_aliases" >> "$shell_rc"
        echo "fi" >> "$shell_rc"
        log "Shell aliases sourcing relocated to end of $shell_rc." "SUCCESS"
    else
        log "Shell aliases sourcing already present at end of $shell_rc."
    fi

}

install_python_env() {
    log "Installing Python environment manager (uv)..."

    # Install uv if not present (brew is prereq for both macOS and Linux)
    if ! is_installed "uv"; then
        log "Installing uv..."
        brew install uv || {
            log "Brew install failed, falling back to curl..." "WARNING"
            curl -LsSf https://astral.sh/uv/install.sh | sh
            export PATH="$HOME/.local/bin:$PATH"
            add_to_path "$HOME/.local/bin" "uv"
        }
        log "uv installed successfully." "SUCCESS"
    else
        log "uv already installed, updating..."
        uv self update || log "Failed to update uv." "WARNING"
    fi

    # Install global tools via uv
    log "Installing global Python tools via uv..."
    uv tool install ipython || log "Failed to install ipython." "WARNING"
    uv tool install jupyterlab || log "Failed to install jupyterlab." "WARNING"

    log "Python environment setup complete." "SUCCESS"
}

install_editor_prereqs() {
    log "Installing editor fonts, all-the-icons fonts, and vim-plug..."

    local font_dir="$GNU_DIR/good_fonts"
    local need_fc_cache=false

    # 1. Install fonts from good_fonts/
    if [[ -d "$font_dir" ]]; then
        if [[ "$OS" == "Darwin" ]]; then
            log "Installing fonts for macOS..."
            while IFS= read -r -d '' font; do
                if cp "$font" "$HOME/Library/Fonts/" 2> /dev/null; then
                    log "Installed: $(basename "$font")"
                else
                    log "Failed to install: $font" "WARNING"
                fi
            done < <(find "$font_dir" -type f \( -name "*.ttf" -o -name "*.otf" \) -print0)
            log "Fonts installed for macOS."
        else
            log "Installing fonts for Linux..."
            mkdir -p "$HOME/.fonts"
            while IFS= read -r -d '' font; do
                if cp "$font" "$HOME/.fonts/" 2> /dev/null; then
                    log "Installed: $(basename "$font")"
                else
                    log "Failed to install: $font" "WARNING"
                fi
            done < <(find "$font_dir" -type f \( -name "*.ttf" -o -name "*.otf" \) -print0)
            need_fc_cache=true
            log "Fonts installed for Linux."
        fi
    else
        log "Font directory $font_dir does not exist. Skipping font installation." "WARNING"
    fi

    # 2. Install all-the-icons fonts for Spacemacs/Emacs (best-effort).
    # This complements the vendored terminal/editor fonts above.
    install_all_the_icons_fonts

    # 3. Install vim-plug
    local vim_plug_file="$HOME/.vim/autoload/plug.vim"
    if [[ ! -f "$vim_plug_file" ]]; then
        log "Installing vim-plug..."
        curl -fLo "$vim_plug_file" --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    else
        log "vim-plug is already installed."
    fi

    # 4. Install Vim plugins
    if command -v vim &> /dev/null; then
        log "Installing Vim plugins..."
        vim +PlugInstall +qall || log "Vim plugin installation failed." "WARNING"
    else
        log "Vim is not installed. Skipping plugin installation." "WARNING"
    fi

    # 5. Install DejaVu Sans Mono for Powerline fonts (from vim-plug)
    local dejavu_dir="$HOME/.vim/plugged/fonts/DejaVuSansMono"
    if [[ -d "$dejavu_dir" ]]; then
        log "Installing DejaVu Sans Mono for Powerline fonts..."
        for font in "$dejavu_dir"/*.ttf "$dejavu_dir"/*.otf; do
            [[ -e "$font" ]] || continue
            if [[ "$OS" == "Darwin" ]]; then
                cp "$font" ~/Library/Fonts/
            else
                mkdir -p "$HOME/.fonts"
                cp "$font" "$HOME/.fonts/"
                need_fc_cache=true
            fi
        done
        log "DejaVu Sans Mono for Powerline fonts installed."
    else
        log "DejaVu Powerline font directory not found. Skipping."
    fi

    # 6. Rebuild font cache once (Linux only)
    if [[ "$need_fc_cache" == true ]]; then
        fc-cache -fv
    fi
}

install_ai_tools() {
    log "Installing AI coding assistant tools..."

    # Claude Code - native installer (recommended over npm)
    log "Installing Claude Code via native installer..."
    curl -fsSL https://claude.ai/install.sh | bash || log "Error installing Claude Code." "WARNING"

    # Other AI tools via npm
    ai_packages=("@openai/codex" "@google/gemini-cli" "opencode-ai")
    for pkg in "${ai_packages[@]}"; do
        log "Installing $pkg via npm..."
        $NODE_CMD install -g "$pkg" || log "Error installing $pkg." "WARNING"
    done

    # Create symlinks for Claude Code config
    log "Setting up Claude Code config..."
    mkdir -p "$HOME/.claude"
    if [[ -f "$GNU_DIR/.claude_global.md" ]]; then
        ln -sf "$GNU_DIR/.claude_global.md" "$HOME/.claude/CLAUDE.md"
        log "Symlinked Claude Code global instructions (CLAUDE.md)."
    else
        log "Claude global config not found at $GNU_DIR/.claude_global.md" "WARNING"
    fi
    if [[ -f "$GNU_DIR/.claude_settings.json" ]]; then
        ln -sf "$GNU_DIR/.claude_settings.json" "$HOME/.claude/settings.json"
        log "Symlinked Claude Code settings (vim mode enabled)."
    else
        log "Claude settings not found at $GNU_DIR/.claude_settings.json" "WARNING"
    fi
    if [[ -f "$GNU_DIR/.claude_statusline.sh" ]]; then
        ln -sf "$GNU_DIR/.claude_statusline.sh" "$HOME/.claude/statusline-command.sh"
        log "Symlinked Claude Code statusline script."
    else
        log "Claude statusline script not found at $GNU_DIR/.claude_statusline.sh" "WARNING"
    fi

    # Copy Codex config (not symlink) — preserves local [projects.*] trust entries
    log "Setting up Codex config..."
    mkdir -p "$HOME/.codex"
    if [[ -f "$GNU_DIR/.codex_config.toml" ]]; then
        local codex_target="$HOME/.codex/config.toml"
        local codex_tmp
        codex_tmp="$(mktemp "$HOME/.codex/config.toml.XXXXXX")"

        # Extract local [projects.*] blocks from existing config (if any)
        local project_blocks=""
        if [[ -f "$codex_target" ]] && [[ -s "$codex_target" ]]; then
            project_blocks="$(sed -n '/^\[projects\./,$p' "$codex_target")"
        fi

        # Remove existing symlink if present (prevents writing through to repo)
        [[ -L "$codex_target" ]] && rm -f "$codex_target"

        # Write base config (everything before first [projects. line in tracked file)
        # Strip trailing blank lines from base to ensure idempotent output
        sed '/^\[projects\./,$d' "$GNU_DIR/.codex_config.toml" |
            awk '{a[NR]=$0} END{e=NR; while(e>0&&a[e]=="")e--; for(i=1;i<=e;i++)print a[i]}' > "$codex_tmp"

        # Append preserved local project blocks with single blank separator
        if [[ -n "$project_blocks" ]]; then
            printf '\n\n%s\n' "$project_blocks" >> "$codex_tmp"
        fi

        # Atomic move
        mv "$codex_tmp" "$codex_target"
        log "Copied Codex config (base settings synced, local project trust preserved)."
    else
        log "Codex config not found at $GNU_DIR/.codex_config.toml" "WARNING"
    fi
    if [[ -f "$GNU_DIR/.codex_instructions.md" ]]; then
        ln -sf "$GNU_DIR/.codex_instructions.md" "$HOME/.codex/instructions.md"
        log "Symlinked Codex instructions (tool preferences)."
    else
        log "Codex instructions not found at $GNU_DIR/.codex_instructions.md" "WARNING"
    fi

    # Install AI notification helper into a stable PATH location
    log "Setting up AI notification helper..."
    mkdir -p "$HOME/.local/bin"
    add_to_path "$HOME/.local/bin" "Local user binaries"
    if [[ -f "$GNU_DIR/notifications/ai-notify-if-unfocused" ]]; then
        ln -sf "$GNU_DIR/notifications/ai-notify-if-unfocused" "$HOME/.local/bin/ai-notify-if-unfocused"
        for helper in "$GNU_DIR"/notifications/ai-notify-if-unfocused "$GNU_DIR"/notifications/backends/*.sh; do
            [[ -f "$helper" ]] && chmod +x "$helper"
        done
        log "Symlinked AI notification helper to ~/.local/bin."
    else
        log "AI notification helper not found at $GNU_DIR/notifications/ai-notify-if-unfocused" "WARNING"
    fi

    # Install tmux helper scripts
    log "Setting up tmux helper scripts..."
    for helper in "$GNU_DIR"/bin/tmux-*; do
        [[ -f "$helper" ]] || continue
        chmod +x "$helper"
        ln -sf "$helper" "$HOME/.local/bin/$(basename "$helper")"
    done
    log "Symlinked tmux helpers to ~/.local/bin."

    # Create symlink for OpenCode config
    log "Setting up OpenCode config..."
    mkdir -p "$HOME/.config/opencode"
    if [[ -f "$GNU_DIR/.opencode.json" ]]; then
        ln -sf "$GNU_DIR/.opencode.json" "$HOME/.config/opencode/opencode.json"
        log "Symlinked OpenCode config (vim mode enabled)."
    else
        log "OpenCode config not found at $GNU_DIR/.opencode.json" "WARNING"
    fi
}

install_neovim_source() {
    log "Delegating to build_neovim.sh..."
    "$GNU_DIR/build_neovim.sh"
}

install_neovim() {
    local install_mode="${NEOVIM_INSTALL_MODE:-source}"

    if [[ "$install_mode" == "package" ]]; then
        install_neovim_package
        return $?
    fi

    install_neovim_source
}

install_neovim_package() {
    log "Installing Neovim and configuring LazyVim..."

    # Source versions.conf for NEOVIM_VERSION
    source "$GNU_DIR/versions.conf"
    local neovim_version="${NEOVIM_VERSION:-0.12.0}"
    local minimum_neovim_version="0.11.2"

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

    get_installed_neovim_version() {
        if ! command -v nvim &> /dev/null; then
            return 1
        fi

        nvim --version 2> /dev/null | head -1 | sed -E 's/^NVIM v([0-9]+(\.[0-9]+){1,2}).*/\1/'
    }

    # LazyVim bootstraps itself via git on first launch, so fail fast if git is
    # not available instead of leaving the user with a broken nvim startup.
    if ! is_installed "git"; then
        log "git is required for Neovim/LazyVim bootstrap, but it is not installed." "ERROR"
        log "Install git first (for example: 'make system-prereq'), then re-run 'make neovim'." "ERROR"
        return 1
    fi

    # Many Mason-managed Neovim tools in this config are distributed via npm
    # (bash-language-server, prettier, html/css/emmet LSPs, markdown tooling).
    # Neovim itself can still run without node/npm, so warn instead of aborting.
    if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
        log "node/npm are not installed. Neovim will work, but some Mason-managed LSPs/formatters will not auto-install." "WARNING"
        log "Install Node.js first (for example: 'make system-prereq' or './prereq_packages.sh install_nodejs') for full Neovim language support." "WARNING"
    fi

    # --- Install Neovim binary ---
    local installed_neovim_version=""
    installed_neovim_version="$(get_installed_neovim_version || true)"

    if [[ -n "$installed_neovim_version" ]] && ! neovim_version_lt "$installed_neovim_version" "$neovim_version"; then
        log "Neovim is already installed: $(nvim --version | head -1)"
    elif is_installed "nvim"; then
        if [[ -n "$installed_neovim_version" ]]; then
            log "Existing Neovim $installed_neovim_version is older than target $neovim_version; upgrading..." "WARNING"
        else
            log "Neovim is installed, but its version could not be detected reliably. Reinstalling target $neovim_version..." "WARNING"
        fi

        if is_installed "brew"; then
            brew upgrade neovim || brew install neovim || log "Error upgrading Neovim via Homebrew." "WARNING"
        elif [[ "$DISTRO" == "arch" ]] && ! no_admin_mode; then
            install_packages "neovim"
        else
            log "Package-managed Neovim cannot be trusted to meet target $neovim_version here; installing pinned user-local build instead." "WARNING"
            installed_neovim_version=""
        fi
    fi

    installed_neovim_version="$(get_installed_neovim_version || true)"

    if [[ -n "$installed_neovim_version" ]] && ! neovim_version_lt "$installed_neovim_version" "$neovim_version"; then
        :
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
            aarch64 | arm64) arch="arm64" ;;
            *)
                log "Unsupported architecture $arch for Neovim download." "ERROR"
                return 1
                ;;
        esac

        local nvim_dest="$HOME/.local/bin/nvim"

        if [[ "$OS" == "Darwin" ]]; then
            # macOS: download tarball (appimage is Linux-only)
            local nvim_url="https://github.com/neovim/neovim/releases/download/v${neovim_version}/nvim-macos-${arch}.tar.gz"
            curl -fsSL "$nvim_url" -o /tmp/nvim-macos.tar.gz || {
                log "Failed to download Neovim for macOS." "ERROR"
                return 1
            }
            local nvim_extract_dir="$HOME/.local/share/nvim-macos"
            rm -rf "$nvim_extract_dir"
            mkdir -p "$nvim_extract_dir"
            tar -xzf /tmp/nvim-macos.tar.gz -C "$nvim_extract_dir" --strip-components=1
            rm -f /tmp/nvim-macos.tar.gz
            ln -sf "$nvim_extract_dir/bin/nvim" "$nvim_dest"
        else
            # Linux: download appimage
            local nvim_url="https://github.com/neovim/neovim/releases/download/v${neovim_version}/nvim-linux-${arch}.appimage"
            curl -fsSL "$nvim_url" -o "$nvim_dest" || {
                log "Failed to download Neovim appimage." "ERROR"
                return 1
            }
            chmod +x "$nvim_dest"

            # Test if FUSE is available; if not, extract the appimage
            if ! "$nvim_dest" --version &> /dev/null; then
                log "FUSE not available, extracting appimage..."
                local extract_dir="$HOME/.local/share/nvim-appimage"
                rm -rf "$extract_dir" /tmp/squashfs-root
                (cd /tmp && "$nvim_dest" --appimage-extract > /dev/null 2>&1) || {
                    log "Failed to extract Neovim appimage." "ERROR"
                    rm -f "$nvim_dest"
                    return 1
                }
                mv /tmp/squashfs-root "$extract_dir"
                rm -f "$nvim_dest"
                ln -sf "$extract_dir/AppRun" "$nvim_dest"
            fi
        fi

        add_to_path "$HOME/.local/bin" "Neovim"
        log "Neovim installed to $nvim_dest" "SUCCESS"
    fi

    installed_neovim_version="$(get_installed_neovim_version || true)"
    if [[ -z "$installed_neovim_version" ]]; then
        log "Neovim install completed, but the version could not be determined from 'nvim --version'." "ERROR"
        return 1
    fi
    if neovim_version_lt "$installed_neovim_version" "$minimum_neovim_version"; then
        log "Neovim $installed_neovim_version is too old for LazyVim. Require >= $minimum_neovim_version." "ERROR"
        return 1
    fi
    if neovim_version_lt "$installed_neovim_version" "$neovim_version"; then
        log "Neovim $installed_neovim_version is older than the repo target $neovim_version." "ERROR"
        return 1
    fi
    log "Neovim version verified: $installed_neovim_version"

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

            if [[ -z "$lg_version" ]]; then
                log "Failed to determine latest lazygit version from GitHub API." "WARNING"
                return 0
            fi

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
                add_to_path "$HOME/.local/bin" "lazygit"
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
    elif [ -e "$nvim_config_dir" ]; then
        log "A non-directory file exists at $nvim_config_dir. Backing it up."
        mv "$nvim_config_dir" "${nvim_config_dir}_backup_$(date +%Y%m%d%H%M%S)"
    fi

    ln -s "$nvim_source" "$nvim_config_dir"
    log "Neovim config symlinked: $nvim_config_dir -> $nvim_source" "SUCCESS"

    log "Neovim setup complete! Run 'nvim' to auto-install plugins and LSP servers on first launch." "SUCCESS"
}

install_all() {
    log "Installing all dependencies..."
    install_editor_prereqs
    setup_wsl_config
    install_homebrew
    install_nodejs
    install_git_credential
    install_askpass
    install_cli_tools
    install_git_prereqs
    install_shell_prereqs
    install_markdown_support
    install_yaml_support
    install_vimscript_lsp
    install_latex_tools
    install_python_prereqs
    install_r_support
    install_c_cpp_prereqs
    install_sql_tools
    install_js_tools
    install_html_css_support
    install_docker_support
    install_kubernetes_support
    install_ocaml_support
    install_terraform_support
    install_ai_tools
}

# Main function to call specific layer based on input
main() {
    valid_functions=(
        "setup_wsl_config"
        "install_wsl_utils"
        "install_homebrew"
        "install_nodejs"
        "install_git_credential"
        "install_askpass"
        "install_shell_prereqs"
        "install_git_prereqs"
        "install_whisper_toolchain"
        "install_whisper_audio_integration"
        "install_whisper_prereqs"
        "install_markdown_support"
        "install_yaml_support"
        "create_snippet_symlink"
        "install_vimscript_lsp"
        "install_latex_tooling"
        "install_latex_distribution"
        "install_latex_tools"
        "install_python_prereqs"
        "install_python_env"
        "install_r_support"
        "install_c_cpp_prereqs"
        "install_sql_tools"
        "install_js_tools"
        "install_html_css_support"
        "install_docker_support"
        "install_kubernetes_support"
        "install_ocaml_support"
        "install_terraform_support"
        "install_rust_support"
        "install_editor_prereqs"
        "install_ai_tools"
        "install_starship"
        "install_syntax_highlighting"
        "install_cli_tools_core"
        "install_cli_tools_system"
        "install_cli_tools"
        "install_neovim_source"
        "install_neovim_package"
        "install_neovim"
        "install_all"
    )

    # Check if the provided function is valid
    if [[ " ${valid_functions[*]} " =~ $1 ]]; then
        "$1" # Call the function dynamically
    else
        echo "Unknown function: $1"
        exit 1
    fi
}

# Run main with the provided argument
main "$1"
