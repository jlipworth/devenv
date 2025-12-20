# ci/Dockerfile
# Base image for devenv CI testing
# Contains all common dependencies for layer tests
#
# Build and push using: ./ci/build-image.sh --push
# Or manually: docker build -t jlipworth/gnu-files-ci:latest -f ci/Dockerfile .

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/home/linuxbrew/.linuxbrew/bin:${PATH}"

# =============================================================================
# Base system packages (needed by most layers)
# NOTE: Language-specific packages (r-base, ocaml, etc.) are NOT included here
# because layer tests should verify their installation works correctly
# =============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build essentials
    make git ca-certificates curl wget gnupg sudo \
    build-essential procps file m4 unzip bubblewrap \
    # CLI tools layer needs
    libtool-bin cmake gpg cloc xclip \
    # Python base (widely used for tooling)
    python3 python3-pip python3-venv pipx \
    # Common dev libraries (needed by multiple layers during compilation)
    libcurl4-openssl-dev libssl-dev libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Node.js LTS (for npm-based language servers)
# =============================================================================
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Homebrew for Linux (for packages not in apt: git-delta, ripgrep, hadolint, etc.)
# Homebrew refuses to run as root, so we create a user, install, then clean up
# =============================================================================
RUN useradd -m -s /bin/bash linuxbrew && \
    echo 'linuxbrew ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER linuxbrew
RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Go via brew (need Go 1.21+ for sqls and other modern Go tools)
RUN /home/linuxbrew/.linuxbrew/bin/brew install go

# Switch back to root for remaining setup
USER root
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"

# Verify installations
RUN node --version && npm --version && go version && brew --version

# Set working directory and fix permissions
WORKDIR /workspace
RUN chown linuxbrew:linuxbrew /workspace

# Run as linuxbrew user by default (has NOPASSWD sudo for apt)
# This allows brew commands to work while sudo apt still functions
USER linuxbrew
