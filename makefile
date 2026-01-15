# Makefile for JAL Emacs Installation

.PHONY: spacemacs prereq-layers-all linking-prereq system-prereq node-manual \
        shell-layer git-layer yaml markdown completion vimscript \
        latex python python-env r c_cpp sql js html_css docker kubernetes ocaml terraform rust ai-tools \
        cli_tools update-deps full-setup help

# Default target to install all prerequisite layers
prereq-layers-all: shell-layer git-layer yaml markdown completion vimscript latex python r c_cpp sql js html_css docker kubernetes ocaml terraform rust ai-tools

cli_tools:
	@echo "Installing CLI tools only..."
	@./prereq_packages.sh install_cli_tools

spacemacs:
	@echo "Triggering spacemacs build script..."
	@./build_emacs30.sh

# Symlink and font prerequisites
linking-prereq:
	@echo "Running linking and font script..."
	@./linking_script.sh


# System prerequisite installations
system-prereq:
	@echo "Installing general system prerequisites..."
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

# Update dependencies after Renovate MRs
update-deps:
	@echo "Updating all dependencies from git..."
	@./update_dependencies.sh

# Group targets for convenience
full-setup: linking-prereq system-prereq prereq-layers-all
	@echo "Completed full system setup."

# Help target
help:
	@echo "JAL Emacs Installation Makefile"
	@echo ""
	@echo "Main targets:"
	@echo "  full-setup        - Complete system setup (linking + system + all layers)"
	@echo "  spacemacs         - Build Emacs 30.1 from source + install Spacemacs"
	@echo "  linking-prereq    - Create symlinks for .vimrc, .spacemacs, install fonts"
	@echo "  system-prereq     - Install system packages (git, nodejs, CLI tools)"
	@echo "  prereq-layers-all - Install all language server prerequisites"
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
	@echo "  terraform   - terraform-ls (pinned to v1.11.0)"
	@echo "  rust        - rust-analyzer, cargo tools"
	@echo "  r           - R/ESS support"
	@echo ""
	@echo "Other targets:"
	@echo "  cli_tools       - Install general CLI tools only"
	@echo "  update-deps     - Update dependencies after Renovate PRs"
