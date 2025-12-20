# macOS CI Setup (TODO)

Future work: Add macOS CI testing to the existing Woodpecker pipeline.

## Why

Currently only Linux CI exists. macOS Emacs builds are untested in CI.

## Options

| Approach | Cost | Setup Effort | Notes |
|----------|------|--------------|-------|
| Self-hosted Mac Mini | $400-500 one-time | Medium | Best performance |
| GitHub Actions | Free (2000 min/mo) | Low | Easiest option |
| Cirrus CI | Free (limited) | Low | Alternative to GH Actions |
| MacStadium / AWS | $50-500/mo | Low | Production/enterprise |

## Recommended: GitHub Actions

Since repo is on GitHub, use free macOS runners.

### Create `.github/workflows/macos.yml`

```yaml
name: macOS Build

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build-emacs:
    runs-on: macos-14  # Apple Silicon

    steps:
      - uses: actions/checkout@v4

      - name: Install Homebrew dependencies
        run: |
          brew update
          brew bundle --file=brewfiles/Brewfile.emacs-30

      - name: Build Emacs
        env:
          CI: "true"
          CI_INSTALL: "true"
        run: |
          chmod +x *.sh
          ./build_emacs30.sh

      - name: Verify build
        run: |
          /usr/local/bin/emacs --version

  test-layers:
    runs-on: macos-14
    strategy:
      fail-fast: false
      matrix:
        layer: [python, js, c_cpp, terraform, docker]

    steps:
      - uses: actions/checkout@v4

      - name: Install layer - ${{ matrix.layer }}
        env:
          CI: "true"
        run: |
          chmod +x *.sh
          make ${{ matrix.layer }}
```

## Alternative: Self-Hosted Woodpecker Agent

If you have a Mac available:

### Install Agent

```bash
brew install woodpecker-agent
```

### Configure

Create `/usr/local/etc/woodpecker-agent/agent.conf`:

```bash
WOODPECKER_SERVER=your-woodpecker-server:9000
WOODPECKER_AGENT_SECRET=your-agent-secret
WOODPECKER_FILTER_LABELS=platform=macos
WOODPECKER_BACKEND=local
```

### Create Launch Daemon

Create `/Library/LaunchDaemons/com.woodpecker.agent.plist` and load with:

```bash
sudo launchctl load /Library/LaunchDaemons/com.woodpecker.agent.plist
```

### Add to .woodpecker.yml

```yaml
- name: build-emacs-macos
  labels:
    platform: macos
  environment:
    CI: "true"
  commands:
    - ./build_emacs30.sh
  when:
    - branch: main
```

## Maintenance

```bash
# Check agent status
sudo launchctl list | grep woodpecker

# View logs
tail -f /var/log/woodpecker-agent.log

# Restart
sudo launchctl stop com.woodpecker.agent
sudo launchctl start com.woodpecker.agent
```
