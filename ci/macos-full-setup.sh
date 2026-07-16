#!/usr/bin/env bash
# Run the full GNU_files setup in an isolated native-macOS workspace.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
mode="${1:-run}"

# Even read-only `brew bundle check` can trigger Homebrew's implicit update
# unless this is set before the first preflight query.
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

usage() {
    cat << 'EOF'
Usage: ci/macos-full-setup.sh [--preflight]

The normal mode runs `make full-setup` with a disposable HOME, a user-local
Emacs prefix, a read-only Homebrew facade, and sudo disabled. It then clones
the configured Spacemacs fork and performs a batch startup smoke test.

--preflight checks the host-provided tools and Brewfiles without installing.
EOF
}

case "$mode" in
    run) ;;
    --preflight) ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        usage >&2
        exit 64
        ;;
esac

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "macOS CI requires a Darwin runner" >&2
    exit 69
fi

for command_name in brew git curl python3 xcode-select; do
    command -v "$command_name" > /dev/null || {
        echo "missing runner prerequisite: $command_name" >&2
        exit 69
    }
done
xcode-select -p > /dev/null

real_brew="$(command -v brew)"
brewfiles=("$repo_root"/brewfiles/Brewfile.*)
for brewfile in "${brewfiles[@]}"; do
    if ! "$real_brew" bundle check --file="$brewfile" > /dev/null; then
        echo "runner provisioning is incomplete for $brewfile" >&2
        exit 69
    fi
done

if [[ "$mode" == "--preflight" ]]; then
    echo "macOS CI preflight passed: Xcode tools and all Brewfiles are present"
    exit 0
fi

workspace="${MACOS_CI_WORKSPACE:-$(mktemp -d "${TMPDIR:-/tmp}/gnu-files-macos-ci.XXXXXX")}"
keep_workspace="${MACOS_CI_KEEP_WORKSPACE:-false}"
guard_bin="$workspace/guard-bin"
guard_log="$workspace/host-mutation-attempts.log"
ci_home="$workspace/home"

cleanup() {
    status=$?
    if [[ "$keep_workspace" == "true" ]]; then
        echo "Keeping macOS CI workspace: $workspace" >&2
    else
        rm -rf "$workspace"
    fi
    exit "$status"
}
trap cleanup EXIT INT TERM

mkdir -p "$guard_bin" "$ci_home" "$ci_home/Library/Fonts"
: > "$guard_log"
ln -s "$repo_root/ci/macos-brew-readonly" "$guard_bin/brew"
ln -s "$repo_root/ci/macos-sudo-deny" "$guard_bin/sudo"

export HOME="$ci_home"
export GNU_DIR="$repo_root"
export EMACS_PREFIX="$HOME/.local/emacs"
export MACOS_CI=true
export NO_ADMIN=true
export CI=true
export CI_INSTALL=true
export MACOS_CI_REAL_BREW="$real_brew"
export MACOS_CI_GUARD_LOG="$guard_log"
export npm_config_prefix="$HOME/.npm-global"
export NPM_CONFIG_PREFIX="$npm_config_prefix"
export PATH="$guard_bin:$EMACS_PREFIX/bin:$HOME/.local/bin:$npm_config_prefix/bin:$PATH"

make -C "$repo_root" full-setup

emacs_bin="$EMACS_PREFIX/bin/emacs"
[[ -x "$emacs_bin" ]] || {
    echo "isolated Emacs binary was not installed at $emacs_bin" >&2
    exit 1
}

git clone --depth 100 --branch develop \
    https://github.com/jlipworth/spacemacs "$HOME/.emacs.d"

# Batch mode normally suppresses user init, so load Spacemacs explicitly. This
# exercises the actual tracked .spacemacs symlink created by `full-setup`.
"$emacs_bin" --batch --load "$HOME/.emacs.d/init.el" \
    --eval '(progn (message "GNU_files macOS Spacemacs smoke passed") (kill-emacs 0))'

if [[ -s "$guard_log" ]]; then
    echo "macOS CI detected an unsafe or missing host prerequisite:" >&2
    cat "$guard_log" >&2
    exit 1
fi

echo "macOS isolated full setup and Spacemacs smoke passed"
