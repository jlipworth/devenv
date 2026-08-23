#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/codex-config-spec.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

(
    cd "$repo_root"
    ./check_codex_config.sh
) > "$tmp/guard.log"

mkdir -p "$tmp/darwin-home/.codex" "$tmp/linux-home/.codex"
cat > "$tmp/darwin-home/.codex/config.toml" << 'EOF'
model = "local-old-value"

[projects."/tmp/one"]
trust_level = "trusted"

[mcp_servers.safari-mcp]
command = "stale-command"
enabled_tools = ["evaluate_javascript"]

[projects."/tmp/two"]
trust_level = "trusted"
EOF

# Exercise only the config installer: no CLI installs and no Safari/WebDriver session.
HOME="$tmp/darwin-home" GNU_DIR="$repo_root" CODEX_CONFIG_OS=Darwin \
    "$repo_root/prereq_packages.sh" install_codex_config > "$tmp/install.log"

python3 - "$tmp/darwin-home/.codex/config.toml" << 'PY'
import re
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    text = handle.read()

assert '[projects."/tmp/one"]\ntrust_level = "trusted"' in text
assert '[projects."/tmp/two"]\ntrust_level = "trusted"' in text
assert text.count("[projects.") == 2
assert "stale-command" not in text
assert "evaluate_javascript" not in text

expected = "\n".join(
    [
        'command = "/usr/bin/safaridriver"',
        'args = ["--mcp"]',
        'enabled_tools = ["create_tab", "list_tabs", "switch_tab", "page_info", '
        '"get_page_content", "screenshot", "wait_for_navigation", '
        '"page_interactions", "close_tab"]',
    ]
)
matches = re.findall(
    r"(?ms)^\[mcp_servers\.safari-mcp\]\n(.*?)(?=^\[|\Z)", text
)
assert len(matches) == 1
assert matches[0].strip() == expected
PY

# A second install must be idempotent and continue preserving project trust.
cp "$tmp/darwin-home/.codex/config.toml" "$tmp/first-install.toml"
HOME="$tmp/darwin-home" GNU_DIR="$repo_root" CODEX_CONFIG_OS=Darwin \
    "$repo_root/prereq_packages.sh" install_codex_config > "$tmp/reinstall.log"
cmp "$tmp/first-install.toml" "$tmp/darwin-home/.codex/config.toml"

# Non-macOS installs must remain valid without referencing Apple's executable.
HOME="$tmp/linux-home" GNU_DIR="$repo_root" CODEX_CONFIG_OS=Linux \
    "$repo_root/prereq_packages.sh" install_codex_config > "$tmp/linux-install.log"
if grep -Eq 'safari-mcp|safaridriver' "$tmp/linux-home/.codex/config.toml"; then
    echo "non-macOS Codex config must omit the Safari MCP server" >&2
    exit 1
fi

# full-setup reaches prereq-layers-all, whose ai-tools layer invokes this installer.
make -C "$repo_root" -n full-setup > "$tmp/full-setup-dry-run.log"
grep -q './prereq_packages.sh install_ai_tools' "$tmp/full-setup-dry-run.log"
grep -q 'make neovim' "$tmp/full-setup-dry-run.log"

echo "Codex config install tests passed"
