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
approval_policy = "never"
notify = ["/Applications/Some.app/wrapper", "turn-ended"]

[tui]
screen_reader_detection_done = true

[plugins."browser@openai-bundled"]
enabled = true

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

# Repo-defined keys win; local-only keys and tables survive. The repo leaves
# model choice to each machine, so a local model is kept.
assert 'model = "local-old-value"' in text
assert text.count("\nmodel = ") == 1
assert 'approval_policy = "never"' in text
assert 'notify = ["/Applications/Some.app/wrapper", "turn-ended"]' in text
assert text.count("[tui]") == 1
tui = re.search(r"(?ms)^\[tui\]\n(.*?)(?=^\[|\Z)", text).group(1)
assert "screen_reader_detection_done = true" in tui
assert "notifications = true" in tui
assert '[plugins."browser@openai-bundled"]\nenabled = true' in text

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

# Non-macOS installs must remain valid without referencing Apple's executable,
# including when an older install left a Safari table behind.
cat > "$tmp/linux-home/.codex/config.toml" << 'EOF'
[mcp_servers.safari-mcp]
command = "/usr/bin/safaridriver"
EOF
HOME="$tmp/linux-home" GNU_DIR="$repo_root" CODEX_CONFIG_OS=Linux \
    "$repo_root/prereq_packages.sh" install_codex_config > "$tmp/linux-install.log"
if grep -Eq 'safari-mcp|safaridriver' "$tmp/linux-home/.codex/config.toml"; then
    echo "non-macOS Codex config must omit the Safari MCP server" >&2
    exit 1
fi

# The merge helper must run on the oldest supported python3 (macOS ships 3.9).
if [[ -x /usr/bin/python3 ]]; then
    /usr/bin/python3 "$repo_root/bin/codex-config-merge" "$repo_root/.codex_config.toml" \
        "$tmp/darwin-home/.codex/config.toml" > /dev/null
fi

# Unsupported TOML (multi-line strings) leaves the existing config untouched.
mkdir -p "$tmp/odd-home/.codex"
printf 'developer_instructions = """\nhello\n"""\n' > "$tmp/odd-home/.codex/config.toml"
cp "$tmp/odd-home/.codex/config.toml" "$tmp/odd-before.toml"
HOME="$tmp/odd-home" GNU_DIR="$repo_root" CODEX_CONFIG_OS=Darwin \
    "$repo_root/prereq_packages.sh" install_codex_config > "$tmp/odd-install.log" 2>&1
cmp "$tmp/odd-before.toml" "$tmp/odd-home/.codex/config.toml"
grep -q "left it unchanged" "$tmp/odd-install.log"

# full-setup reaches prereq-layers-all, whose ai-tools layer invokes this installer.
make -C "$repo_root" -n full-setup > "$tmp/full-setup-dry-run.log"
grep -q './prereq_packages.sh install_ai_tools' "$tmp/full-setup-dry-run.log"
grep -q 'make neovim' "$tmp/full-setup-dry-run.log"

echo "Codex config install tests passed"
