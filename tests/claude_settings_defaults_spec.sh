#!/usr/bin/env bash
# bin/claude-settings-defaults must merge managed keys (commit/PR attribution)
# into existing Claude Code settings without touching other keys, stay
# idempotent, create missing settings, and report drift under --check.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
script="$repo_root/bin/claude-settings-defaults"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/claude-settings-defaults-spec.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

# Existing settings: managed key merged, everything else preserved.
home="$tmp/home"
mkdir -p "$home/.claude"
settings="$home/.claude/settings.json"
cp "$repo_root/.claude_settings.json" "$settings"
python3 - "$settings" << 'PY'
import json, sys
path = sys.argv[1]
data = json.load(open(path))
data["attribution"] = {"commit": "Co-Authored-By: someone", "pr": ""}
data["permissions"] = {"allow": ["Bash(ls:*)"]}
json.dump(data, open(path, "w"))
PY
chmod 640 "$settings"

if HOME="$home" python3 "$script" --check 2> "$tmp/check.err"; then
    echo "--check passed on drifted settings" >&2
    exit 1
fi
grep -q 'attribution' "$tmp/check.err"

HOME="$home" python3 "$script" > "$tmp/apply.log"
grep -q 'Updated' "$tmp/apply.log"
python3 - "$settings" "$repo_root/.claude_settings.json" << 'PY'
import json, sys
data = json.load(open(sys.argv[1]))
template = json.load(open(sys.argv[2]))
assert data.pop("attribution") == {"commit": "", "pr": ""}
assert data.pop("permissions") == {"allow": ["Bash(ls:*)"]}
assert data == template, data
PY
[ "$(python3 -c 'import os,sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$settings")" = 0o640 ]

# Idempotent: second run is silent and leaves the file byte-identical.
cp "$settings" "$tmp/first.json"
HOME="$home" python3 "$script" > "$tmp/reapply.log"
[ ! -s "$tmp/reapply.log" ]
cmp "$settings" "$tmp/first.json"
HOME="$home" python3 "$script" --check

# Missing file (fresh service account): created with only the managed keys.
fresh="$tmp/svc/.claude/settings.json"
python3 - "$fresh" < "$script"
python3 -c 'import json,sys; assert json.load(open(sys.argv[1])) == {"attribution": {"commit": "", "pr": ""}}' "$fresh"

# Unknown flags are rejected rather than treated as a path.
if python3 "$script" --bogus 2> /dev/null; then
    echo "unknown flag accepted" >&2
    exit 1
fi

# ai-tools layer must invoke the merge.
grep -q 'bin/claude-settings-defaults' "$repo_root/prereq_packages.sh"

echo "Claude settings defaults tests passed"
