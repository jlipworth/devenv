# Makefile for JAL Emacs Installation

.PHONY: spacemacs prereq-layers-all editor-symlinks editor system-prereq node-manual \
        shell-layer git-layer yaml markdown completion vimscript \
        latex python python-env r c_cpp sql js html_css docker kubernetes ocaml terraform rust ai-tools \
        whisper whisper_toolchain whisper_audio latex_tooling latex_distribution \
        cli_tools cli_tools_core cli_tools_system starship syntax-highlighting update-deps \
        full-setup noadmin-setup help neovim neovim-source neovim-package

# Default target to install all prerequisite layers
prereq-layers-all: editor shell-layer git-layer yaml markdown completion vimscript latex python r c_cpp sql js html_css docker kubernetes ocaml terraform rust ai-tools

cli_tools:
	@echo "Installing CLI tools only..."
	@./prereq_packages.sh install_cli_tools

cli_tools_core:
	@echo "Installing core CLI tools..."
	@./prereq_packages.sh install_cli_tools_core

cli_tools_system:
	@echo "Installing CLI system-integration extras..."
	@./prereq_packages.sh install_cli_tools_system

starship:
	@echo "Installing Starship prompt..."
	@./prereq_packages.sh install_starship

syntax-highlighting:
	@echo "Installing shell syntax highlighting..."
	@./prereq_packages.sh install_syntax_highlighting

spacemacs:
	@echo "Triggering spacemacs build script..."
	@./build_emacs30.sh

# Editor config symlinks (early foundation step)
editor-symlinks:
	@echo "Creating editor symlinks..."
	@ln -sf "$$(pwd)/.vimrc" "$$HOME/.vimrc"
	@ln -sf "$$(pwd)/.spacemacs" "$$HOME/.spacemacs"

# Editor fonts and vim-plug
editor:
	@echo "Installing editor fonts and vim-plug..."
	@./prereq_packages.sh install_editor_prereqs


# System prerequisite installations
system-prereq:
	@echo "Installing general system prerequisites..."
	@./prereq_packages.sh install_wsl_utils
	@./prereq_packages.sh install_homebrew
	@./prereq_packages.sh install_cli_tools
	@./prereq_packages.sh install_git_credential
	@./prereq_packages.sh install_askpass
	@./prereq_packages.sh install_nodejs

# Need to see if wsl path adjustment is really what is wanted
# @./prereq_packages.sh setup_wsl_config
node-manual:
	@echo "Installing node and npm only..."
	@./prereq_packages.sh install_nodejs

# Layers prerequisites
shell-layer:
	@echo "Installing shell-layer prerequisites..."
	@./prereq_packages.sh install_shell_prereqs

git-layer:
	@echo "Installing git-layer prerequisites..."
	@./prereq_packages.sh install_git_prereqs

whisper:
	@echo "Installing Whisper (speech-to-text) prerequisites..."
	@./prereq_packages.sh install_whisper_prereqs

whisper_toolchain:
	@echo "Installing Whisper toolchain only..."
	@./prereq_packages.sh install_whisper_toolchain

whisper_audio:
	@echo "Installing Whisper audio integration prerequisites..."
	@./prereq_packages.sh install_whisper_audio_integration

yaml:
	@echo "Installing YAML language server..."
	@./prereq_packages.sh install_yaml_support

markdown:
	@echo "Installing Markdown support..."
	@./prereq_packages.sh install_markdown_support

completion:
	@echo "Creating Yasnippet symbolic link..."
	@./prereq_packages.sh create_snippet_symlink

vimscript:
	@echo "Installing Vimscript language server..."
	@./prereq_packages.sh install_vimscript_lsp

latex:
	@echo "Installing LaTeX tools..."
	@./prereq_packages.sh install_latex_tools

latex_tooling:
	@echo "Installing LaTeX editor/tooling support..."
	@./prereq_packages.sh install_latex_tooling

latex_distribution:
	@echo "Installing LaTeX distribution support..."
	@./prereq_packages.sh install_latex_distribution

python:
	@echo "Installing Python tools..."
	@./prereq_packages.sh install_python_prereqs

python-env:
	@echo "Installing Python environment (uv)..."
	@./prereq_packages.sh install_python_env

r:
	@echo "Installing R/ESS prerequisites..."
	@./prereq_packages.sh install_r_support

c_cpp:
	@echo "Installing C/C++ prerequisites..."
	@./prereq_packages.sh install_c_cpp_prereqs

sql:
	@echo "Installing SQL tools..."
	@./prereq_packages.sh install_sql_tools

js:
	@echo "Installing JavaScript language server..."
	@./prereq_packages.sh install_js_tools

html_css:
	@echo "Installing HTML and CSS language servers..."
	@./prereq_packages.sh install_html_css_support

docker:
	@echo "Installing Docker and related tools..."
	@./prereq_packages.sh install_docker_support

kubernetes:
	@echo "Installing Kubernetes tools..."
	@./prereq_packages.sh install_kubernetes_support

ocaml:
	@echo "Installing OCaml and Opam..."
	@./prereq_packages.sh install_ocaml_support

terraform:
	@echo "Installing Terraform..."
	@./prereq_packages.sh install_terraform_support

rust:
	@echo "Installing Rust development tools..."
	@./prereq_packages.sh install_rust_support

ai-tools:
	@echo "Installing AI coding assistant tools..."
	@./prereq_packages.sh install_ai_tools

neovim:
	@echo "Installing Neovim and configuring LazyVim (source-build default on Unix)..."
	@./prereq_packages.sh install_neovim

neovim-source:
	@echo "Building Neovim from source and configuring LazyVim..."
	@./prereq_packages.sh install_neovim_source

neovim-package:
	@echo "Installing Neovim and configuring LazyVim via package/download path..."
	@NEOVIM_INSTALL_MODE=package ./prereq_packages.sh install_neovim

# Update dependencies after Renovate MRs
update-deps:
	@echo "Updating all dependencies from git..."
	@./update_dependencies.sh

# Sequential setup of foundations, followed by parallel layers
full-setup:
	@echo "Starting sequential foundations..."
	@$(MAKE) editor-symlinks
	@$(MAKE) system-prereq
	@echo "Foundations complete. Starting sequential layer installation..."
	@$(MAKE) prereq-layers-all
	@echo "Completed full system setup."

# No-admin setup: full install without sudo-requiring steps
noadmin-setup:
	@NO_ADMIN=true $(MAKE) full-setup

# Help target
help:
	@echo "JAL Emacs Installation Makefile"
	@echo ""
	@echo "Main targets:"
	@echo "  full-setup        - Complete system setup (linking + system + all layers)"
	@echo "  noadmin-setup     - Full setup without sudo (skips system packages)"
	@echo "  spacemacs         - Build Emacs 30.1 from source + install Spacemacs"
	@echo "  editor-symlinks   - Create symlinks for .vimrc and .spacemacs"
	@echo "  system-prereq     - Install system packages (git, nodejs, CLI tools)"
	@echo "  prereq-layers-all - Install all language server prerequisites"
	@echo ""
	@echo "Environment variables:"
	@echo "  NO_ADMIN=true     - Prefix any target to skip sudo-requiring steps"
	@echo "                      (e.g. NO_ADMIN=true make latex)"
	@echo ""
	@echo "Language layers:"
	@echo "  python      - Python LSP, debugpy, linters"
	@echo "  python-env  - uv package manager + global tools"
	@echo "  c_cpp       - clangd/LLVM for C/C++"
	@echo "  js          - TypeScript, Prettier, ESLint"
	@echo "  sql         - sqls language server"
	@echo "  latex       - texlab, TeXLive/MacTeX"
	@echo "  docker      - dockerfile-language-server, hadolint"
	@echo "  kubernetes  - kubectl, argocd, k9s, kubectx, stern"
	@echo "  ocaml       - OCaml + opam + merlin"
	@echo "  terraform   - terraform, terraform-ls"
	@echo "  rust        - rust-analyzer, cargo tools"
	@echo "  r           - R/ESS support"
	@echo ""
	@echo "Other targets:"
	@echo "  editor          - Install fonts and vim-plug"
	@echo "  whisper         - Install Whisper prerequisites (toolchain + audio integration unless NO_ADMIN=true)"
	@echo "  whisper_toolchain - Install Whisper toolchain only"
	@echo "  whisper_audio   - Install Whisper audio integration prerequisites"
	@echo "  cli_tools       - Install general CLI tools only (core + system extras unless NO_ADMIN=true)"
	@echo "  cli_tools_core  - Install core user-space CLI tools"
	@echo "  cli_tools_system - Install optional CLI system-integration extras"
	@echo "  latex_tooling   - Install LaTeX editor/tooling support"
	@echo "  latex_distribution - Install LaTeX distribution support"
	@echo "  starship        - Install Starship prompt with Ayu Mirage config"
	@echo "  syntax-highlighting - Install shell syntax highlighting (blesh/zsh-syntax-highlighting)"
	@echo "  update-deps     - Update dependencies after Renovate PRs"
	@echo "  neovim          - Build pinned Neovim from source + LazyVim (default Unix path)"
	@echo "  neovim-source   - Explicit source-build alias for pinned Neovim + LazyVim"
	@echo "  neovim-package  - Legacy package/download Neovim + LazyVim path"
