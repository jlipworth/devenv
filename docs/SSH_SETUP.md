# SSH Key Setup

Quick reference for setting up SSH keys on a new machine.

## Generate Key

```bash
ssh-keygen -t ed25519 -C "devenv_$(hostname)" -f ~/.ssh/devenv_ed25519
```

## Add to SSH Agent

```bash
# Start agent
eval "$(ssh-agent -s)"

# Add key
ssh-add ~/.ssh/devenv_ed25519
```

## Copy Public Key to Clipboard

```bash
# macOS
pbcopy < ~/.ssh/devenv_ed25519.pub

# Linux (requires xclip)
xclip -selection clipboard < ~/.ssh/devenv_ed25519.pub

# Linux (requires xsel)
xsel --clipboard < ~/.ssh/devenv_ed25519.pub

# Fallback: just display it
cat ~/.ssh/devenv_ed25519.pub
```

## Add to GitHub/GitLab

1. Copy the public key (above)
2. GitHub: Settings > SSH and GPG keys > New SSH key
3. GitLab: Preferences > SSH Keys > Add new key

## Test Connection

```bash
ssh -T git@github.com
ssh -T git@gitlab.com
```

## Persist Agent (Linux)

Add to `~/.bashrc` or `~/.zshrc`:

```bash
# SSH Agent Setup
if ! pgrep -x "ssh-agent" >/dev/null; then
    eval "$(ssh-agent -s)"
fi
ssh-add ~/.ssh/devenv_ed25519 2>/dev/null
```
