#!/usr/bin/env bash

set -euo pipefail

config_file=".codex_config.toml"

if [[ ! -f "$config_file" ]]; then
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

echo "Codex config guard passed: no local [projects.*] blocks found."
