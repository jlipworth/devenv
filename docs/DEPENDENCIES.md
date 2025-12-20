# Dependency Management

This document describes how dependencies are managed in this repository and how to keep them up to date.

## Overview

This repository manages **80+ dependencies** across multiple package managers to support Emacs 30.1 + Spacemacs with language server support for 13+ programming languages.

## Dependency Files

### Structured Dependency Files (Renovate-Compatible)

These files contain version-pinnable dependencies that can be automatically updated:

| File | Purpose | Manager |
|------|---------|---------|
| `requirements.txt` | Python packages (pyright, debugpy, etc.) | Renovate |
| `brewfiles/Brewfile.*` | Homebrew packages for macOS (per-layer) | Renovate |
| `renovate.json` | Renovate bot configuration | - |

### Shell Script Dependencies (Manual Management)

These require manual updates:

- **`build_emacs30.sh`** - Emacs 30.1 and build dependencies
- **`prereq_packages.sh`** - apt packages, language-specific tools
- **`common_utils.sh`** - Package manager setup

## Automated Updates with Renovate

### How It Works

**Weekly Schedule** (Mondays before 6am):
- Renovate checks for Python and Homebrew updates
- Creates grouped pull requests by package manager

**Monthly Schedule** (1st of month):
- Major version updates reviewed separately
- Requires manual approval (no auto-merge)

**Auto-Merge Policy**:
- Minor/patch updates: Auto-merge after CI passes
- Major updates: Manual review required

### After Renovate Updates

```bash
cd ~/GNU_files
git pull
make js          # Updates JavaScript packages
make python      # Updates Python packages
```

### Pause or Ignore Updates

```json
// In renovate.json - pause all updates
{ "enabled": false }

// Ignore specific package
{
  "packageRules": [{
    "matchPackageNames": ["problematic-package"],
    "enabled": false
  }]
}
```

## Renovate Integration Status

### Integrated Layers

| Layer | Command | Dependency File | Status |
|-------|---------|-----------------|--------|
| **Python** | `make python` | requirements.txt | Integrated |
| **Homebrew** | various | brewfiles/Brewfile.* | Integrated |

### Non-Integrated Layers

These use npm global installs or platform package managers:
- JavaScript, Shell, YAML, Vimscript, HTML/CSS, Docker, AI Tools
- LaTeX, C/C++, SQL, OCaml, Terraform

## Manual Dependency Updates

### npm Packages (Global)

```bash
npm update -g                  # Update global packages
npm outdated -g                # Check for updates
```

### Python Packages

```bash
pip install --upgrade -r requirements.txt
pipx upgrade pyright           # Update specific package
pip list --outdated            # Check for updates
```

### Homebrew (macOS)

```bash
brew bundle install            # Install from Brewfile
brew update && brew upgrade    # Update all
brew outdated                  # Check for updates
```

### apt Packages (Linux)

```bash
sudo apt update && sudo apt upgrade
```

## Version Pinning

All pinned versions are managed in `versions.conf`:

```bash
# versions.conf
EMACS_VERSION="30.1"
TERRAFORM_VERSION="1.11.0"
GCC_VERSION="auto"
```

### Terraform (Pinned: 1.11.0)

Terraform is pinned to ensure compatibility with the Proxmox provider.

**Why Pinned**: Version 1.11.0 has been verified to work correctly with the current Proxmox setup.

**Excluded from Renovate**: Terraform is excluded from automatic updates in `renovate.json`.

**To Change Version**:
1. Edit `TERRAFORM_VERSION` in `versions.conf`
2. Run `make terraform`
3. Verify with `terraform version`

**Update Guidance**:
- Patch updates (1.11.x): Generally safe
- Minor updates (1.12.x): Check Proxmox provider compatibility first
- Major updates (2.x): Test extensively

### Emacs (Pinned: 30.1)

**To Change Version**:
1. Edit `EMACS_VERSION` in `versions.conf`
2. Run `make spacemacs`
3. Verify Spacemacs compatibility

### GCC (Linux)

**To Change Version**:
- Set `GCC_VERSION="auto"` to detect highest available (default)
- Or pin to specific version: `GCC_VERSION="14"`

### Rolling Latest (not pinned)

- All language servers
- All npm/Python/Homebrew packages

## Dependency Inventory

| Category | Count | Examples |
|----------|-------|----------|
| npm (global) | 14+ | typescript, prettier, language servers |
| Python | 6+ | pyright, debugpy, flake8 |
| Homebrew | 40+ | CLI tools, build dependencies |
| apt | 30+ | System libraries, compilers |
| Go | 1+ | sqls |
| OCaml | 4+ | merlin, utop, ocamlformat |

## Troubleshooting

### Renovate Not Creating PRs

1. Check Renovate logs in Woodpecker CI
2. Verify `renovate.json` is valid
3. Check rate limits (prHourlyLimit: 2)

### Dependency Conflicts

```json
// Pin problematic package in renovate.json
{
  "matchPackageNames": ["problematic-package"],
  "allowedVersions": "<=1.2.3"
}
```

### Build Failures After Updates

```bash
rm -rf ~/.emacs.d
make full-setup

# Debug specific layer
./prereq_packages.sh install_python_prereqs 2>&1 | tee logs.txt
```

## Best Practices

1. **Review before merging**: Check breaking changes in release notes
2. **Test locally first**: Run `make prereq-layers-all` before committing
3. **Update in batches**: Don't let dependencies get too far behind
4. **Pin problematic packages**: If a package breaks often, pin it

## CI Image Rebuild Checklist

When Renovate creates PRs that update dependencies in `ci/Dockerfile` or when you need to manually update the CI base image:

### When to Rebuild

- [ ] Base image updated (e.g., `debian:bookworm-slim` version change)
- [ ] New system packages needed by layer tests
- [ ] Node.js LTS version update
- [ ] Go version update (for sqls and other Go tools)
- [ ] Homebrew packages added to base image

### Rebuild Steps

1. Review the changes in `ci/Dockerfile`
2. Test locally: `./ci/build-image.sh` (builds for local arch only)
3. Build and push multi-arch: `./ci/build-image.sh --push`
4. Verify the new image works: trigger a manual CI run
5. Merge the Renovate PR after CI passes

### Image Details

- **Registry:** Docker Hub (`jlipworth/gnu-files-ci`)
- **Platforms:** linux/amd64, linux/arm64
- **Tags:** `latest` and date-based (e.g., `2024.01.15`)

## Resources

- [Renovate Documentation](https://docs.renovatebot.com/)
- [Terraform Releases](https://releases.hashicorp.com/terraform/)
- [Proxmox Provider GitHub](https://github.com/Telmate/terraform-provider-proxmox)
