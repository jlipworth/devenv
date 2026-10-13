#!/bin/sh

set -eu

config_file=".codex_config.toml"

if [ ! -f "$config_file" ]; then
    echo "ERROR: $config_file not found." >&2
    exit 1
fi

if grep -nE '^\[projects\.' "$config_file" >&2; then
    cat >&2 << 'EOF'
ERROR: .codex_config.toml must remain a shared base config only.

Tracked .codex_config.toml may not contain any [projects.*] blocks because
those are machine-local trust entries written by Codex and belong only in:
  ~/.codex/config.toml

Fix:
  1. Remove the [projects.*] block(s) from .codex_config.toml
  2. Keep local trust entries only in ~/.codex/config.toml
EOF
    exit 1
fi

tier_lines="$(awk '/^\[/ { exit } /^[[:space:]]*service_tier[[:space:]]*=/ { print }' "$config_file")"
if [ "$tier_lines" != 'service_tier = "default"' ]; then
    if grep -nE '^[[:space:]]*service_tier[[:space:]]*=.*(priority|fast)' "$config_file" >&2; then
        echo "ERROR: .codex_config.toml must not default Codex to Fast/priority/ultrafast." >&2
    fi
    cat >&2 << 'EOF'
ERROR: .codex_config.toml must set exactly one top-level line:
  service_tier = "default"
Fast/priority/ultrafast must remain an explicit per-session choice; the shared
base pins normal speed so a stale local Fast toggle cannot survive make ai-tools.
EOF
    exit 1
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/codex-config-guard.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

cat > "$tmp_dir/expected" << 'EOF'
command = "/usr/bin/safaridriver"
args = ["--mcp"]
enabled_tools = ["create_tab", "list_tabs", "switch_tab", "page_info", "get_page_content", "screenshot", "wait_for_navigation", "page_interactions", "close_tab"]
EOF

if ! awk '
    $0 == "[mcp_servers.safari-mcp]" {
        count++
        capture = 1
        next
    }
    capture && /^\[/ { capture = 0 }
    capture { print }
    END { if (count != 1) exit 1 }
' "$config_file" > "$tmp_dir/actual" || ! cmp -s "$tmp_dir/expected" "$tmp_dir/actual"; then
    echo "ERROR: [mcp_servers.safari-mcp] must contain only the approved safaridriver" >&2
    echo "command, --mcp argument, and navigation/read-only tool allowlist." >&2
    exit 1
fi

echo "Codex config guard passed: shared-only config, normal service tier, and restricted Safari MCP allowlist verified."
