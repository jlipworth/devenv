#!/bin/bash

source common_utils.sh

# WSL-specific setup
setup_wsl_config() {
    if grep -q WSL /proc/version; then
        log "Checking WSL configuration..."
        # Check if /etc/wsl.conf contains the appendwindowspath setting
        if grep -q "appendwindowspath = false" /etc/wsl.conf 2> /dev/null; then
            log "WSL configuration already set. No changes made."
        else
            log "Configuring WSL to disable Windows PATH inheritance..."
            echo -e "[interop]\nappendwindowspath = false" | sudo tee -a /etc/wsl.conf
            log "WSL configuration updated successfully."
        fi
    fi
}

# Install Homebrew on Linux
install_homebrew() {
    if [[ "$OS" == "Linux" ]]; then
        if ! is_installed "brew"; then
            log "Installing Homebrew for Linux..."
            # TODO: Need to see if CI=1 works in a desktop environment. Using to bypass passwordless sudo.
            CI=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            add_to_path "/home/linuxbrew/.linuxbrew/bin" "Homebrew (Linux)"
        else
            log "Homebrew is already installed."
        fi
    fi
}

# Install NodeJS and NPM for both macOS and Linux using latest Node.js setup
install_nodejs() {
    log "Installing NodeJS and NPM..."

    if [[ "$OS" == "Linux" ]]; then
        # Safer approach: download script first, verify, then execute
        local setup_script
        setup_script=$(mktemp)
        trap "rm -f '$setup_script'" RETURN

        log "Downloading NodeSource setup script..."
        if ! curl -fsSL https://deb.nodesource.com/setup_current.x -o "$setup_script"; then
            log "Failed to download NodeSource setup script." "ERROR"
            return 1
        fi

        # Basic verification that it's a NodeSource script
        if ! grep -q "nodesource" "$setup_script"; then
            log "Downloaded script doesn't appear to be from NodeSource. Aborting." "ERROR"
            return 1
        fi

        log "Running NodeSource setup script..."
        sudo bash "$setup_script" || {
            log "NodeSource setup failed." "ERROR"
            return 1
        }
    fi

    # Brew should install nodejs current version
    install_packages "nodejs" "npm"
    # Easier to upgrade just rolling over npm manually
    npm update -g
}

install_git_credential() {
    if [[ "$OS" == "Linux" ]]; then
        log "Installing Git credential helper for Linux..."
        install_packages "libsecret-1-0" "libsecret-1-dev" "gnome-keyring"
        sudo make -C /usr/share/doc/git/contrib/credential/libsecret
        sudo cp /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret /usr/local/bin
        git config --global credential.helper libsecret
    else
        log "Skipping Git credential helper setup. macOS uses the built-in keychain."
    fi
}

install_askpass() {
    if [[ "$OS" == "Linux" ]]; then
        log "Installing ksshaskpass..."
        install_packages "ksshaskpass"
    else
        log "Skipping askpass. I don't think MacOS uses this."
    fi
}

# Install prerequisites grouped by category
install_shell_prereqs() {
    log "Installing shell prerequisites..."
    install_packages "shellcheck" "shfmt"
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

install_yaml_support() {
    log "Installing YAML language server..."
    $NODE_CMD install -g yaml-language-server || log "Error installing yaml-language-server." "WARNING"
}

install_markdown_support() {
    log "Installing markdown support..."
    # Pandoc for live preview in Spacemacs markdown layer (optional but useful)
    if is_installed "brew"; then
        brew install pandoc || log "Error installing pandoc." "WARNING"
    else
        install_packages "pandoc"
    fi

    # Mermaid CLI for rendering mermaid diagrams in markdown
    log "Installing mermaid-cli for diagram rendering..."
    $NODE_CMD install -g @mermaid-js/mermaid-cli || log "Error installing mermaid-cli." "WARNING"
}

create_snippet_symlink() {
    log "Creating symbolic link for Yasnippet directory..."
    EMACS_SNIPPETS_DIR="$HOME/.emacs.d/private/snippets"
    TARGET_DIR="$GNU_DIR/snippets/"

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

install_latex_tools() {
    log "Installing LaTeX tools..."
    if [[ "$OS" == "Darwin" ]]; then
        # Use Brewfile for LaTeX tools
        if is_installed "brew"; then
            log "Installing LaTeX tools via Homebrew..."
            brew bundle --file="$GNU_DIR/brewfiles/Brewfile.latex" || log "Error with Brewfile.latex" "WARNING"
        fi

        # Add common LaTeX packages similar to texlive-latex-extra
        log "Installing common LaTeX packages via tlmgr..."
        eval "$(/usr/libexec/path_helper)" # Ensure tlmgr is in PATH
        sudo tlmgr update --self
        # Install essential packages: latexextra for functionality, basic font packages only
        # Use amsfonts and ec (European Computer Modern) instead of full collection-fontsrecommended
        sudo tlmgr install collection-latexextra amsfonts ec cm-super
    else
        # Install minimal LaTeX with latex-extra for common packages
        install_packages "texlive-latex-extra" "okular" "aspell"

        # Install texlab from pre-built binary (not available in apt)
        if ! is_installed "texlab"; then
            log "Installing texlab from GitHub releases..."
            TEXLAB_VERSION=$(curl -s https://api.github.com/repos/latex-lsp/texlab/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
            TEXLAB_URL="https://github.com/latex-lsp/texlab/releases/download/v${TEXLAB_VERSION}/texlab-x86_64-linux.tar.gz"

            curl -L "$TEXLAB_URL" -o /tmp/texlab.tar.gz || {
                log "Failed to download texlab." "ERROR"
                return 1
            }
            tar -xzf /tmp/texlab.tar.gz -C /tmp || {
                log "Failed to extract texlab." "ERROR"
                return 1
            }
            sudo mv /tmp/texlab /usr/local/bin/ || {
                log "Failed to move texlab to /usr/local/bin." "ERROR"
                return 1
            }
            sudo chmod +x /usr/local/bin/texlab
            rm /tmp/texlab.tar.gz
            log "texlab installed successfully." "SUCCESS"
        else
            log "texlab is already installed."
        fi
    fi
}

install_python_prereqs() {
    log "Installing Python tools..."
    if [[ "$OS" == "Darwin" ]]; then
        # macOS: pip comes with python3, ipython is handled by install_python_env
        install_packages "python3" "pipx"
    else
        # Linux: needs python3-pip separately
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
        python_packages=("pyright" "debugpy" "autoflake" "flake8" "jupytext")
        for pkg in "${python_packages[@]}"; do
            log "Installing $pkg via pip..."
            $PIP_CMD "$pkg" || log "Error installing Python package $pkg." "WARNING"
        done
    fi

    # Add Python bin directory to PATH
    PYTHON_BIN_DIR="$(python3 -m site --user-base)/bin"
    add_to_path "$PYTHON_BIN_DIR" "Python binaries (pipx)"
}

install_r_support() {
    log "Installing R tools for ESS..."

    if [[ "$OS" == "Darwin" ]]; then
        install_packages "r"
    else
        install_packages "r-base" "r-base-dev" "libcurl4-openssl-dev" "libssl-dev" "libxml2-dev"
    fi

    if is_installed "Rscript"; then
        log "Ensuring the R languageserver package is installed..."
        # Create user library directory if it doesn't exist
        Rscript -e 'dir.create(Sys.getenv("R_LIBS_USER"), showWarnings = FALSE, recursive = TRUE)'
        # Install to user library to avoid permission issues
        Rscript -e 'if (!requireNamespace("languageserver", quietly = TRUE)) install.packages("languageserver", repos = "https://cloud.r-project.org", lib = Sys.getenv("R_LIBS_USER"))' ||
            log "Failed to install languageserver package for R." "WARNING"
    else
        log "Rscript not found on PATH; skipping languageserver install." "WARNING"
    fi
}

install_c_cpp_prereqs() {
    log "Installing C/C++ prerequisites..."
    if is_installed "brew"; then
        log "Installing C/C++ tools via Homebrew..."
        brew bundle --file="$GNU_DIR/brewfiles/Brewfile.c_cpp" || log "Error with Brewfile.c_cpp" "WARNING"
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

# TODO: Figure out DAP mechanism
install_js_tools() {
    log "Installing JavaScript tools..."

    # JavaScript language servers and tools (always install latest)
    local js_packages=(
        "import-js"
        "typescript"
        "typescript-language-server"
        "prettier"
        "js-beautify"
        "flow-bin"
    )

    for pkg in "${js_packages[@]}"; do
        log "Installing $pkg via npm..."
        $NODE_CMD install -g "$pkg" || log "Error installing $pkg." "WARNING"
    done

    log "JavaScript tools installed successfully." "SUCCESS"
}

install_html_css_support() {
    log "Installing HTML and CSS language servers..."
    html_css_packages=("vscode-css-languageserver-bin" "vscode-html-languageserver-bin")
    for pkg in "${html_css_packages[@]}"; do
        log "Installing $pkg via npm..."
        $NODE_CMD install -g "$pkg" || log "Error installing $pkg." "WARNING"
    done
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

    # Source pinned version from versions.conf
    if [[ -f "$GNU_DIR/versions.conf" ]]; then
        source "$GNU_DIR/versions.conf"
    fi
    TERRAFORM_VERSION="${TERRAFORM_VERSION:-1.11.0}"

    if [[ $OS == "Linux" ]]; then
        log "Installing terraform \"repo\"..."
        # Add GPG key
        if [[ ! -f /usr/share/keyrings/hashicorp-archive-keyring.gpg ]]; then
            wget -qO- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
        fi
        # Add repository - detect distro codename from /etc/os-release
        # Works for both Debian (bookworm, bullseye) and Ubuntu (focal, jammy, noble)
        DISTRO_CODENAME=$(grep -oP '(?<=VERSION_CODENAME=).+' /etc/os-release || echo "bookworm")
        if ! grep -q "https://apt.releases.hashicorp.com" /etc/apt/sources.list.d/hashicorp.list 2> /dev/null; then
            log "Adding HashiCorp apt repository for $DISTRO_CODENAME..."
            echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $DISTRO_CODENAME main" |
                sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
        fi

        # Install specific version for Proxmox compatibility
        log "Installing Terraform version $TERRAFORM_VERSION (pinned for Proxmox)..."
        sudo apt update -qq
        sudo apt install -y terraform="$TERRAFORM_VERSION" || {
            log "Failed to install Terraform $TERRAFORM_VERSION. Trying latest..." "WARNING"
            install_packages "terraform"
        }

        # terraform-ls can be latest
        install_packages "terraform-ls"

        # Cloud provider CLIs via Brewfile (Linuxbrew)
        if is_installed "brew"; then
            if [[ -f "$GNU_DIR/brewfiles/Brewfile.terraform" ]]; then
                log "Installing cloud provider CLIs via Linuxbrew..."
                brew bundle --file="$GNU_DIR/brewfiles/Brewfile.terraform" || log "Error with Brewfile.terraform" "WARNING"
            fi
        fi

    elif [[ $OS == "Darwin" ]]; then
        log "Adding HashiCorp tap to Homebrew..."
        brew tap hashicorp/tap || log "Error adding hashicorp/tap." "WARNING"

        # Install specific version for Proxmox compatibility
        log "Installing Terraform version $TERRAFORM_VERSION (pinned for Proxmox)..."
        if ! is_installed "terraform" || [[ $(terraform version -json 2> /dev/null | grep -o '"version":"[^"]*' | cut -d'"' -f4) != "$TERRAFORM_VERSION" ]]; then
            # Use brew install-formula-from-api for specific versions
            brew install terraform@"$TERRAFORM_VERSION" 2> /dev/null || {
                log "Version-specific formula not available. Installing via direct download..." "WARNING"

                # Direct download and install (fallback)
                TF_URL="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_darwin_$(uname -m | sed 's/x86_64/amd64/;s/arm64/arm64/').zip"
                TF_DIR="/usr/local/bin"

                log "Downloading Terraform $TERRAFORM_VERSION from HashiCorp..."
                curl -fsSL "$TF_URL" -o /tmp/terraform.zip &&
                    unzip -o /tmp/terraform.zip -d /tmp &&
                    sudo mv /tmp/terraform "$TF_DIR/terraform" &&
                    sudo chmod +x "$TF_DIR/terraform" &&
                    rm /tmp/terraform.zip &&
                    log "Terraform $TERRAFORM_VERSION installed successfully." "SUCCESS" ||
                    log "Failed to install Terraform $TERRAFORM_VERSION." "ERROR"
            }
        else
            log "Terraform $TERRAFORM_VERSION is already installed."
        fi

        # terraform-ls can be latest
        install_packages "terraform-ls"

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

install_cli_tools() {
    log "Installing general CLI tools..."

    # Get shell RC file and shell name for use throughout function
    local shell_rc
    local shell_name
    shell_rc="$(get_shell_rc)"
    shell_name="$(get_shell_name)"

    if [[ "$OS" == "Darwin" ]]; then
        # Install system packages first
        install_packages "htop" "gpg" "cloc"

        # Use Brewfile for CLI tools
        if is_installed "brew"; then
            log "Installing CLI tools via Homebrew..."
            brew bundle --file="$GNU_DIR/brewfiles/Brewfile.cli_tools" || log "Error with Brewfile.cli_tools" "WARNING"
        fi

        if ! xcode-select -p &> /dev/null; then
            log "Xcode Command Line Tools not found. Installing..."
            xcode-select --install || log "Error installing Xcode Command Line Tools." "WARNING"
        else
            log "Xcode Command Line Tools are already installed."
        fi
    else
        # Install system packages via apt
        install_packages "htop" "gpg" "cloc" "cups" "cups-client" "lpr" "xclip" "libtool-bin" "cmake"

        # Use Brewfile for CLI tools on Linux
        if is_installed "brew"; then
            log "Installing CLI tools via Homebrew..."
            brew bundle --file="$GNU_DIR/brewfiles/Brewfile.cli_tools" || log "Error with Brewfile.cli_tools" "WARNING"
        fi
    fi

    # Configure shell aliases
    log "Setting up shell aliases..."
    if [ ! -L "$HOME/.shell_aliases" ]; then
        ln -sf "$GNU_DIR/.shell_aliases" "$HOME/.shell_aliases"
        log "Created symlink for .shell_aliases"
    else
        log ".shell_aliases symlink already exists."
    fi

    # Add sourcing of aliases to shell RC if not already present
    if ! grep -q 'source.*\.shell_aliases' "$shell_rc" 2> /dev/null; then
        log "Adding .shell_aliases sourcing to $shell_rc..."
        echo "" >> "$shell_rc"
        echo "# Load custom shell aliases" >> "$shell_rc"
        echo "if [ -f ~/.shell_aliases ]; then" >> "$shell_rc"
        echo "    source ~/.shell_aliases" >> "$shell_rc"
        echo "fi" >> "$shell_rc"
        log "Shell aliases sourcing added to $shell_rc." "SUCCESS"
    else
        log "Shell aliases sourcing already present in $shell_rc."
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

}

install_python_env() {
    log "Installing Python data analysis environment (miniconda + poetry)..."

    local MINICONDA_DIR="$HOME/miniconda3"
    local shell_rc
    shell_rc="$(get_shell_rc)"

    # Install miniconda if not already installed
    if [[ ! -d "$MINICONDA_DIR" ]]; then
        log "Installing Miniconda..."

        if [[ "$OS" == "Darwin" ]]; then
            # macOS ARM only (M1/M2/M3)
            MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh"
        else
            # Linux - check architecture
            if [[ "$(uname -m)" == "aarch64" ]]; then
                MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh"
            else
                MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
            fi
        fi

        # Download and install miniconda
        if [[ "$OS" == "Darwin" ]]; then
            curl -fsSL "$MINICONDA_URL" -o /tmp/miniconda.sh || {
                log "Failed to download Miniconda." "ERROR"
                return 1
            }
        else
            wget "$MINICONDA_URL" -O /tmp/miniconda.sh || {
                log "Failed to download Miniconda." "ERROR"
                return 1
            }
        fi

        bash /tmp/miniconda.sh -b -p "$MINICONDA_DIR" || {
            log "Failed to install Miniconda." "ERROR"
            return 1
        }

        rm /tmp/miniconda.sh
        log "Miniconda installed successfully." "SUCCESS"

        # Initialize conda for shell
        "$MINICONDA_DIR/bin/conda" init "$(basename "$SHELL")" || log "Failed to initialize conda." "WARNING"

    else
        log "Miniconda is already installed at $MINICONDA_DIR."
    fi

    # Add conda to PATH for this session
    export PATH="$MINICONDA_DIR/bin:$PATH"

    # Accept conda Terms of Service
    log "Accepting conda Terms of Service..."
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main 2> /dev/null || true
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r 2> /dev/null || true

    # Update conda
    log "Updating conda..."
    conda update -n base -c defaults conda -y || log "Failed to update conda." "WARNING"

    log "Ensuring Conda data analysis tools are installed..."
    local conda_tools=("ipython" "jupyterlab")
    for tool in "${conda_tools[@]}"; do
        if conda list --name base "$tool" 2> /dev/null | grep -Eq "^${tool}[[:space:]]"; then
            log "$tool already present in base environment."
        else
            log "Installing $tool via conda..."
            conda install -n base -y "$tool" || log "Failed to install $tool via conda." "WARNING"
        fi
    done

    # Install poetry if not already installed
    if ! is_installed "poetry"; then
        log "Installing Poetry..."

        # Install poetry via pip (recommended method)
        if is_installed "pipx"; then
            # Prefer pipx if available (isolated installation)
            pipx install poetry || {
                log "Failed to install poetry via pipx. Trying curl method..." "WARNING"
                curl -sSL https://install.python-poetry.org | python3 - || log "Failed to install Poetry." "ERROR"
            }
        else
            # Fall back to official installer
            curl -sSL https://install.python-poetry.org | python3 - || log "Failed to install Poetry." "ERROR"
        fi

        # Add poetry to PATH for current session and future sessions
        POETRY_BIN="$HOME/.local/bin"
        if [[ -d "$POETRY_BIN" ]]; then
            export PATH="$POETRY_BIN:$PATH"
            add_to_path "$POETRY_BIN" "Poetry"
        fi

        log "Poetry installed successfully." "SUCCESS"
    else
        log "Poetry is already installed."

        # Update poetry
        log "Updating Poetry..."
        poetry self update || log "Failed to update Poetry." "WARNING"
    fi

    # Configure poetry to create virtual environments in project directories
    poetry config virtualenvs.in-project true || log "Failed to configure poetry." "WARNING"

    log "Python data analysis environment setup complete." "SUCCESS"
    log "NOTE: You may need to restart your shell or run 'source $shell_rc' for conda to work." "WARNING"
}

install_ai_tools() {
    log "Installing AI coding assistant tools..."
    ai_packages=("@anthropic-ai/claude-code" "@openai/codex" "@google/gemini-cli")
    for pkg in "${ai_packages[@]}"; do
        log "Installing $pkg via npm..."
        $NODE_CMD install -g "$pkg" || log "Error installing $pkg." "WARNING"
    done
}

install_all() {
    log "Installing all dependencies..."
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
    install_ocaml_support
    install_terraform_support
    install_ai_tools
}

# Main function to call specific layer based on input
main() {
    valid_functions=(
        "setup_wsl_config"
        "install_homebrew"
        "install_nodejs"
        "install_git_credential"
        "install_askpass"
        "install_shell_prereqs"
        "install_git_prereqs"
        "install_markdown_support"
        "install_yaml_support"
        "create_snippet_symlink"
        "install_vimscript_lsp"
        "install_latex_tools"
        "install_python_prereqs"
        "install_python_env"
        "install_r_support"
        "install_c_cpp_prereqs"
        "install_sql_tools"
        "install_js_tools"
        "install_html_css_support"
        "install_docker_support"
        "install_ocaml_support"
        "install_terraform_support"
        "install_rust_support"
        "install_ai_tools"
        "install_cli_tools"
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
