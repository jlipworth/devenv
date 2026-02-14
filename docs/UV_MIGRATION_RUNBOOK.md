# UV Migration Runbook

Migrate from conda + poetry to uv on each machine.

## Prerequisites

- Pull latest repo changes (with updated `prereq_packages.sh`, `makefile`, `.spacemacs`)

## Steps

### 1. Remove Conda

```bash
# Delete miniconda directory
rm -rf ~/miniconda3

# Remove conda init block from shell rc
# Edit ~/.zshrc (or ~/.bashrc) and delete this block:
#
# # >>> conda initialize >>>
# # !! Contents within this block are managed by 'conda init' !!
# __conda_setup="$('..../miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
# ...
# # <<< conda initialize <<<
```

### 2. Remove Poetry (optional, when ready)

```bash
# If installed via pipx
pipx uninstall poetry

# If installed via official installer
curl -sSL https://install.python-poetry.org | python3 - --uninstall

# Remove from PATH in shell rc if manually added
```

### 3. Install uv

```bash
make python-env
```

This installs:
- `uv` (via brew when available on macOS/Linuxbrew, otherwise via curl installer)
- Global tools: `ipython`, `jupyterlab`

### 4. Verify

```bash
# uv installed
uv --version

# Global tools work
ipython --version
jupyter --version

# Conda gone
which conda  # should return nothing

# Poetry gone (if removed)
which poetry  # should return nothing
```

### 5. Create Test Environment (optional)

```bash
mkdir -p ~/uv-test && cd ~/uv-test
uv init
uv add ipython numpy pandas

# Use it
uv run ipython
# or
source .venv/bin/activate
```

## Spacemacs Notes

- uv support is via `emacs-pet` (auto-detects `.venv` directories)
- No special config needed - just use `uv init` in projects
- The conda layer has been removed from `.spacemacs`

## Quick Reference

| Old | New |
|-----|-----|
| `conda create -n myenv` | `uv init` (in project dir) |
| `conda activate myenv` | `source .venv/bin/activate` |
| `conda install pkg` | `uv add pkg` |
| `poetry add pkg` | `uv add pkg` |
| `poetry install` | `uv sync` |
| `poetry run cmd` | `uv run cmd` |
