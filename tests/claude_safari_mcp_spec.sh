#!/usr/bin/env bash
# install_claude_safari_mcp must register safaridriver --mcp with Claude Code
# and Claude Desktop, enforce the Codex tool allowlist via Claude Code
# permissions, stay idempotent, and do nothing off macOS.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/claude-safari-mcp-spec.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

home="$tmp/darwin-home"
mkdir -p "$home/.claude"
printf '{"numStartups": 3, "mcpServers": {"other": {"command": "x"}}}\n' > "$home/.claude.json"
cp "$repo_root/.claude_settings.json" "$home/.claude/settings.json"

# Stub safaridriver --mcp: answers initialize and tools/list over stdio.
cat > "$tmp/safaridriver" << 'EOF'
#!/usr/bin/env python3
import json, sys
tools = ["create_tab", "list_tabs", "switch_tab", "page_info", "get_page_content",
         "screenshot", "wait_for_navigation", "page_interactions", "close_tab",
         "evaluate_javascript", "read_console", "network_requests", "handle_dialog"]
for line in sys.stdin:
    msg = json.loads(line)
    if msg.get("id") == 1:
        print(json.dumps({"jsonrpc": "2.0", "id": 1, "result": {"protocolVersion": "2025-06-18",
              "capabilities": {}, "serverInfo": {"name": "safari", "version": "0"}}}), flush=True)
    elif msg.get("id") == 2:
        print(json.dumps({"jsonrpc": "2.0", "id": 2,
              "result": {"tools": [{"name": n} for n in tools]}}), flush=True)
EOF
chmod +x "$tmp/safaridriver"

run() {
    HOME="$home" GNU_DIR="$repo_root" CODEX_CONFIG_OS="$1" SAFARIDRIVER_BIN="$tmp/safaridriver" \
        "$repo_root/prereq_packages.sh" install_claude_safari_mcp
}

run Darwin > "$tmp/install.log"

python3 - "$home" << 'PY'
import json, sys
from pathlib import Path

home = Path(sys.argv[1])
entry = {"command": "/usr/bin/safaridriver", "args": ["--mcp"]}

code = json.loads((home / ".claude.json").read_text())
assert code["numStartups"] == 3 and code["mcpServers"]["other"] == {"command": "x"}
assert code["mcpServers"]["safari-mcp"] == {"type": "stdio", "env": {}, **entry}

desktop = json.loads((home / "Library/Application Support/Claude/claude_desktop_config.json").read_text())
assert desktop["mcpServers"]["safari-mcp"] == entry

settings = json.loads((home / ".claude/settings.json").read_text())
assert settings["hooks"] and settings["effortLevel"] == "xhigh"  # unrelated keys preserved
allowed = ["create_tab", "list_tabs", "switch_tab", "page_info", "get_page_content",
           "screenshot", "wait_for_navigation", "page_interactions", "close_tab"]
assert settings["permissions"]["allow"] == sorted(f"mcp__safari-mcp__{t}" for t in allowed)
assert settings["permissions"]["deny"] == sorted(
    f"mcp__safari-mcp__{t}" for t in ["evaluate_javascript", "read_console", "network_requests", "handle_dialog"])
PY

# Idempotent: a second run must not rewrite any file.
for f in ".claude.json" ".claude/settings.json" "Library/Application Support/Claude/claude_desktop_config.json"; do
    cp "$home/$f" "$tmp/$(basename "$f").first"
done
run Darwin > "$tmp/reinstall.log"
grep -q 'already registered' "$tmp/reinstall.log"
grep -q 'already current' "$tmp/reinstall.log"
for f in ".claude.json" ".claude/settings.json" "Library/Application Support/Claude/claude_desktop_config.json"; do
    cmp "$home/$f" "$tmp/$(basename "$f").first"
done

# Non-macOS: no Claude configs touched.
home="$tmp/linux-home"
mkdir -p "$home"
run Linux > "$tmp/linux.log"
[ ! -e "$home/.claude.json" ]
[ ! -e "$home/Library" ]

# ai-tools layer must invoke the installer.
grep -q '^    install_claude_safari_mcp$' "$repo_root/prereq_packages.sh"

echo "Claude Safari MCP install tests passed"
