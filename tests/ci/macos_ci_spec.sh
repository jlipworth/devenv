#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/macos-ci-spec.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/brew" << 'EOF'
#!/usr/bin/env bash
case "$1" in
    bundle) [[ "$2" == check ]] ;;
    list) [[ "$*" == *missing* ]] && exit 1 || printf 'present 1.0\n' ;;
    tap) printf 'hashicorp/tap\n' ;;
    --prefix) printf '/opt/homebrew\n' ;;
    *) exit 0 ;;
esac
EOF
chmod +x "$tmp/brew"
: > "$tmp/guard.log"

export MACOS_CI_REAL_BREW="$tmp/brew"
export MACOS_CI_GUARD_LOG="$tmp/guard.log"
guard="$repo_root/ci/macos-brew-readonly"

"$guard" bundle --file=fake
"$guard" install present
"$guard" tap hashicorp/tap
[[ "$($guard --prefix)" == /opt/homebrew ]]
[[ ! -s "$tmp/guard.log" ]]

if "$guard" install missing; then
    echo "missing package should fail" >&2
    exit 1
fi
grep -q 'missing preinstalled Homebrew package: missing' "$tmp/guard.log"

: > "$tmp/guard.log"
if "$guard" upgrade present; then
    echo "upgrade should be blocked" >&2
    exit 1
fi
grep -q 'blocked mutating Homebrew command' "$tmp/guard.log"

"$repo_root/ci/macos-full-setup.sh" --help | grep -q -- '--preflight'
grep -q 'event: \[manual\]' "$repo_root/.woodpecker/macos.yml"
grep -q 'platform: darwin/arm64' "$repo_root/.woodpecker/macos.yml"
grep -q 'backend: local' "$repo_root/.woodpecker/macos.yml"
python3 "$repo_root/ci/validate-macos-pipeline.py" \
    "$repo_root/.woodpecker/macos.yml" --default-branch master
grep -q 'MACOS_CI_WORKSPACE' "$repo_root/ci/macos-full-setup.sh"
grep -q 'EMACS_PREFIX=' "$repo_root/ci/macos-full-setup.sh"

echo "macOS CI guard tests passed"
