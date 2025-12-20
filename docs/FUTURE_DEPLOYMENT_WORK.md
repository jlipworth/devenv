# Deployment Runbook: Portable Emacs Environment

This runbook documents strategies for deploying the GNU_files Emacs environment to new machines quickly and reproducibly.

## Table of Contents

1. [Overview](#overview)
2. [Current State](#current-state)
3. [Nix + Home Manager Setup](#nix--home-manager-setup)
4. [Alternative: Docker Approach](#alternative-docker-approach)
5. [Alternative: Ansible Automation](#alternative-ansible-automation)
6. [Migration Path](#migration-path)

---

## Overview

### Goal

Deploy a complete Emacs 30.1 + Spacemacs environment to any Linux or macOS machine with:
- Native GUI performance (fonts, icons, ligatures)
- All language servers pre-configured
- Identical configuration across machines
- Minimal manual setup time

### Requirements

| Requirement | Priority |
|-------------|----------|
| GUI Emacs with proper font rendering | High |
| all-the-icons, nerd-fonts | High |
| 15+ language servers | High |
| Works on Linux and macOS | High |
| Reproducible (same versions everywhere) | Medium |
| Fast setup on new machine (<15 min) | Medium |
| Offline install capability | Low |

---

## Current State

The repository currently uses shell scripts for setup:

```
GNU_files/
├── build_emacs30.sh      # Compile Emacs from source
├── prereq_packages.sh    # Install language servers
├── linking_script.sh     # Symlink configs, install fonts
├── common_utils.sh       # Shared utilities
└── makefile              # Orchestration
```

**Pros:**
- Full control over build process
- Works on both platforms
- Well-tested

**Cons:**
- Requires ~30-60 min compilation on each machine
- Version drift between machines possible
- No easy rollback mechanism

---

## Nix + Home Manager Setup

Nix provides declarative, reproducible package management. Home Manager extends it to manage dotfiles and user environments.

### Why Nix?

| Feature | Benefit |
|---------|---------|
| Declarative | Entire environment defined in code |
| Reproducible | Exact same versions on every machine |
| Rollback | Instant rollback to previous generations |
| Atomic | Updates either fully succeed or don't apply |
| Cross-platform | Works on Linux and macOS |

### Step 1: Install Nix

**Linux:**
```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

**macOS:**
```bash
sh <(curl -L https://nixos.org/nix/install)
```

After installation, restart your shell or run:
```bash
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

### Step 2: Enable Flakes

Flakes are the modern way to manage Nix configurations.

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

### Step 3: Install Home Manager

```bash
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
nix-shell '<home-manager>' -A install
```

### Step 4: Create Flake Configuration

Create a new directory for your Nix configuration (or add to GNU_files):

```
nix/
├── flake.nix           # Main flake definition
├── flake.lock          # Locked versions (auto-generated)
├── home.nix            # Home Manager configuration
└── modules/
    ├── emacs.nix       # Emacs-specific config
    ├── fonts.nix       # Font configuration
    └── languages.nix   # Language servers
```

#### `flake.nix`

```nix
{
  description = "GNU_files Emacs development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, emacs-overlay, ... }:
    let
      # Support both Linux and macOS
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    in {
      homeConfigurations = {
        # Linux configuration
        "jlipworth@linux" = home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            system = "x86_64-linux";
            overlays = [ emacs-overlay.overlays.default ];
          };
          modules = [ ./home.nix ];
        };

        # macOS configuration
        "jlipworth@macos" = home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            system = "aarch64-darwin";  # Apple Silicon
            overlays = [ emacs-overlay.overlays.default ];
          };
          modules = [ ./home.nix ];
        };
      };
    };
}
```

#### `home.nix`

```nix
{ config, pkgs, lib, ... }:

{
  home.username = "jlipworth";
  home.homeDirectory = if pkgs.stdenv.isDarwin then "/Users/jlipworth" else "/home/jlipworth";
  home.stateVersion = "24.05";

  # Import modular configs
  imports = [
    ./modules/emacs.nix
    ./modules/fonts.nix
    ./modules/languages.nix
  ];

  # Let Home Manager manage itself
  programs.home-manager.enable = true;
}
```

#### `modules/emacs.nix`

```nix
{ config, pkgs, lib, ... }:

{
  programs.emacs = {
    enable = true;
    # Use Emacs 30 with native compilation and pgtk (Wayland-native on Linux)
    package = pkgs.emacs30-pgtk;

    # Extra Emacs packages that need native compilation
    extraPackages = epkgs: with epkgs; [
      vterm
      treesit-grammars.with-all-grammars
      pdf-tools
    ];
  };

  # Spacemacs
  home.file.".emacs.d" = {
    source = pkgs.fetchFromGitHub {
      owner = "syl20bnr";
      repo = "spacemacs";
      rev = "develop";  # Or pin to specific commit
      sha256 = ""; # Will error first time, Nix will tell you the correct hash
    };
    recursive = true;
  };

  # Your .spacemacs config
  home.file.".spacemacs".source = ../dotfiles/.spacemacs;

  # Snippets
  home.file.".emacs.d/private/snippets".source = ../snippets;
}
```

#### `modules/fonts.nix`

```nix
{ config, pkgs, ... }:

{
  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    # Nerd Fonts (includes programming ligatures + icons)
    (nerdfonts.override { fonts = [
      "JetBrainsMono"
      "FiraCode"
      "Hack"
      "Inconsolata"
      "SourceCodePro"
    ]; })

    # Emacs-specific icon fonts
    emacs-all-the-icons-fonts

    # Additional fonts
    font-awesome
    material-design-icons
  ];
}
```

#### `modules/languages.nix`

```nix
{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    # ─────────────────────────────────────────────
    # Shell
    # ─────────────────────────────────────────────
    bash-language-server
    shellcheck
    shfmt

    # ─────────────────────────────────────────────
    # Python
    # ─────────────────────────────────────────────
    python3
    python3Packages.pip
    pyright
    python3Packages.debugpy
    black
    isort
    ruff

    # ─────────────────────────────────────────────
    # JavaScript / TypeScript
    # ─────────────────────────────────────────────
    nodejs_20
    nodePackages.typescript
    nodePackages.typescript-language-server
    nodePackages.prettier
    nodePackages.eslint

    # ─────────────────────────────────────────────
    # C / C++
    # ─────────────────────────────────────────────
    clang-tools  # includes clangd
    lldb
    cmake
    gnumake

    # ─────────────────────────────────────────────
    # Rust
    # ─────────────────────────────────────────────
    rustc
    cargo
    rust-analyzer
    rustfmt

    # ─────────────────────────────────────────────
    # Go
    # ─────────────────────────────────────────────
    go
    gopls
    gotools

    # ─────────────────────────────────────────────
    # SQL
    # ─────────────────────────────────────────────
    sqls

    # ─────────────────────────────────────────────
    # Terraform
    # ─────────────────────────────────────────────
    terraform
    terraform-ls

    # ─────────────────────────────────────────────
    # Docker
    # ─────────────────────────────────────────────
    nodePackages.dockerfile-language-server-nodejs
    hadolint

    # ─────────────────────────────────────────────
    # LaTeX
    # ─────────────────────────────────────────────
    texlab
    texlive.combined.scheme-medium

    # ─────────────────────────────────────────────
    # YAML / JSON / Markdown
    # ─────────────────────────────────────────────
    yaml-language-server
    nodePackages.vscode-json-languageserver
    marksman

    # ─────────────────────────────────────────────
    # HTML / CSS
    # ─────────────────────────────────────────────
    nodePackages.vscode-html-languageserver-bin
    nodePackages.vscode-css-languageserver-bin

    # ─────────────────────────────────────────────
    # OCaml
    # ─────────────────────────────────────────────
    ocaml
    opam
    ocamlPackages.merlin
    ocamlPackages.utop
    ocamlformat

    # ─────────────────────────────────────────────
    # R
    # ─────────────────────────────────────────────
    R
    rPackages.languageserver

    # ─────────────────────────────────────────────
    # General CLI tools
    # ─────────────────────────────────────────────
    ripgrep
    fd
    fzf
    bat
    eza
    delta
    jq
    yq
    htop
    tree
  ];

  # Ensure binaries are in PATH
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/go/bin"
  ];
}
```

### Step 5: Deploy to a New Machine

```bash
# 1. Install Nix (see Step 1)

# 2. Clone your config
git clone git@gitlab.com:jlipworth/GNU_files.git ~/GNU_files
cd ~/GNU_files/nix

# 3. Build and activate
# On Linux:
nix build .#homeConfigurations."jlipworth@linux".activationPackage
./result/activate

# On macOS:
nix build .#homeConfigurations."jlipworth@macos".activationPackage
./result/activate

# Or use home-manager directly after first setup:
home-manager switch --flake .#jlipworth@linux
```

### Step 6: Updating

```bash
# Update flake inputs (nixpkgs, home-manager, etc.)
nix flake update

# Rebuild
home-manager switch --flake .#jlipworth@linux

# Rollback if something breaks
home-manager generations  # List available generations
home-manager switch --rollback
```

---

## Alternative: Docker Approach

For cases where Nix isn't feasible, Docker provides containerized portability.

### Dockerfile

```dockerfile
# ci/Dockerfile.portable
FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/root

# Install Emacs build dependencies
RUN apt-get update && apt-get install -y \
    build-essential libgtk-3-dev libgnutls28-dev \
    libtiff5-dev libgif-dev libjpeg-dev libpng-dev \
    libxpm-dev libncurses-dev texinfo libjansson-dev \
    libgccjit-12-dev gcc-12 g++-12 libtree-sitter-dev \
    libharfbuzz-dev libcairo2-dev libxml2-dev \
    make sudo curl git wget ca-certificates \
    nodejs npm python3 python3-pip python3-venv \
    fontconfig fonts-noto-color-emoji \
    && rm -rf /var/lib/apt/lists/*

# Copy and run build scripts
WORKDIR /setup
COPY build_emacs30.sh common_utils.sh prereq_packages.sh ./
COPY good_fonts/ ./good_fonts/
RUN chmod +x *.sh && ./build_emacs30.sh

# Install language servers
RUN ./prereq_packages.sh install_all_prereqs

# Install fonts
RUN mkdir -p /usr/share/fonts/truetype/custom && \
    cp good_fonts/*.ttf /usr/share/fonts/truetype/custom/ 2>/dev/null || true && \
    cp good_fonts/*.otf /usr/share/fonts/truetype/custom/ 2>/dev/null || true && \
    fc-cache -fv

# Install Spacemacs
RUN git clone --depth 1 --branch develop \
    https://github.com/syl20bnr/spacemacs /root/.emacs.d

# Copy user config
COPY .spacemacs /root/.spacemacs
COPY snippets/ /root/.emacs.d/private/snippets/

WORKDIR /workspace
ENTRYPOINT ["emacs"]
```

### Running with X11

**Linux:**
```bash
docker run -it --rm \
    -e DISPLAY=$DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v $HOME/projects:/workspace \
    -v $HOME/.gitconfig:/root/.gitconfig:ro \
    gnu-files-emacs
```

**macOS (requires XQuartz):**
```bash
# Install XQuartz: brew install --cask xquartz
# Enable "Allow connections from network clients" in XQuartz preferences
# Restart XQuartz

xhost +localhost
docker run -it --rm \
    -e DISPLAY=host.docker.internal:0 \
    -v $HOME/projects:/workspace \
    gnu-files-emacs
```

### Limitations

- Clipboard integration requires extra setup
- Font rendering may differ slightly from native
- Startup slower than native Emacs
- File watching (for auto-revert) needs volume mounts

---

## Alternative: Ansible Automation

Ansible can orchestrate your existing shell scripts across multiple machines.

### `playbooks/emacs-setup.yml`

```yaml
---
- name: Deploy GNU_files Emacs environment
  hosts: all
  vars:
    gnu_files_repo: "git@gitlab.com:jlipworth/GNU_files.git"
    gnu_files_dir: "{{ ansible_env.HOME }}/GNU_files"

  tasks:
    - name: Install git
      package:
        name: git
        state: present
      become: yes

    - name: Clone GNU_files repository
      git:
        repo: "{{ gnu_files_repo }}"
        dest: "{{ gnu_files_dir }}"
        version: main
        accept_hostkey: yes

    - name: Run full setup
      command: make full-setup
      args:
        chdir: "{{ gnu_files_dir }}"
      environment:
        CI: "false"

    - name: Verify Emacs installation
      command: emacs --version
      register: emacs_version
      changed_when: false

    - name: Display Emacs version
      debug:
        msg: "Installed: {{ emacs_version.stdout_lines[0] }}"
```

### Usage

```bash
# Install Ansible
pip install ansible

# Create inventory
echo "newmachine.local ansible_user=jlipworth" > inventory.ini

# Run playbook
ansible-playbook -i inventory.ini playbooks/emacs-setup.yml
```

---

## Migration Path

### Phase 1: Prepare (Current)

- [x] Shell scripts working for Linux and macOS
- [x] CI testing all layers
- [ ] Document all dependencies with versions
- [ ] Create `requirements.lock` or similar for pinning

### Phase 2: Nix Exploration

- [ ] Install Nix on one machine
- [ ] Create basic `flake.nix` with just Emacs
- [ ] Add language servers incrementally
- [ ] Test on both Linux and macOS

### Phase 3: Full Migration

- [ ] Complete Home Manager configuration
- [ ] Migrate `.spacemacs` management to Nix
- [ ] Add fonts to Nix config
- [ ] Document rollback procedures

### Phase 4: Cleanup

- [ ] Archive shell scripts (keep for reference/CI)
- [ ] Update CI to optionally use Nix
- [ ] Document new setup process

---

## Quick Reference

### Nix Commands

```bash
# Update all inputs
nix flake update

# Build without activating
nix build .#homeConfigurations."jlipworth@linux".activationPackage

# Switch to new generation
home-manager switch --flake .#jlipworth@linux

# List generations
home-manager generations

# Rollback
home-manager switch --rollback

# Garbage collect old generations
nix-collect-garbage -d
```

### Useful Resources

- [Nix Manual](https://nixos.org/manual/nix/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix Emacs Overlay](https://github.com/nix-community/emacs-overlay)
- [Zero to Nix](https://zero-to-nix.com/) - Beginner-friendly guide
- [Nix Pills](https://nixos.org/guides/nix-pills/) - Deep dive

---

## Notes

### Why Not Guix?

Guix is similar to Nix but uses Scheme. It's actually very Emacs-friendly (written by Emacs users). However:
- Smaller package repository than Nixpkgs
- Less macOS support
- Steeper learning curve if you don't know Scheme

Consider Guix if you're interested in a more Emacs-aligned philosophy.

### Terraform Considerations

Your `renovate.json` pins Terraform for Proxmox compatibility. In Nix:

```nix
# Pin specific Terraform version
terraform = pkgs.terraform.overrideAttrs (old: {
  version = "1.11.0";
  src = pkgs.fetchFromGitHub {
    owner = "hashicorp";
    repo = "terraform";
    rev = "v1.11.0";
    sha256 = "...";
  };
});
```
