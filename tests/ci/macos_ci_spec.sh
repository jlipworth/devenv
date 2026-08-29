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

cat > "$tmp/uname" << 'EOF'
#!/usr/bin/env bash
printf 'Darwin\n'
EOF
cat > "$tmp/present" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$tmp/uname" "$tmp/present"
PATH="$tmp:$PATH" MACOS_CI=true CI=true GNU_DIR="$repo_root" \
    bash -c 'source "$GNU_DIR/common_utils.sh"; install_packages present' \
    > "$tmp/install-packages.log"
grep -q 'using runner-provisioned Homebrew metadata' "$tmp/install-packages.log"
grep -q 'skipping host upgrades in macOS CI' "$tmp/install-packages.log"

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
grep -q 'EMACS_APP_DIR="$HOME/Applications"' "$repo_root/ci/macos-full-setup.sh"
grep -q 'vterm-always-compile-module t' "$repo_root/ci/macos-full-setup.sh"
grep -q "advice-add 'pdf-tools-install" "$repo_root/ci/macos-full-setup.sh"
grep -q 'chmod -R u+w "$workspace"' "$repo_root/ci/macos-full-setup.sh"
grep -q '^brew "libgccjit"$' "$repo_root/brewfiles/Brewfile.emacs-30"
grep -q 'ts_language_version=ts_language_abi_version' "$repo_root/build_emacs30.sh"
grep -q 'managed snippets-only ~/.emacs.d skeleton' "$repo_root/build_emacs30.sh"
grep -q 'Existing non-Spacemacs ~/.emacs.d requires interactive review' "$repo_root/build_emacs30.sh"
grep -q 'EMACS_REDOWNLOAD:-false' "$repo_root/build_emacs30.sh"
if grep -q 'Redownload & replace?' "$repo_root/build_emacs30.sh"; then
    echo "existing Emacs sources must be reused without prompting during a resume" >&2
    exit 1
fi
grep -q 'EMACS_APP_DIR:-/Applications' "$repo_root/build_emacs30.sh"
grep -q 'ditto "$EMACS_APP_SOURCE" "$app_stage"' "$repo_root/build_emacs30.sh"
grep -q '.Emacs.app.previous' "$repo_root/build_emacs30.sh"
if grep -q 'ditto "$EMACS_APP_SOURCE" "$EMACS_APP_DESTINATION"' "$repo_root/build_emacs30.sh"; then
    echo "the installed app bundle must replace rather than merge into an old bundle" >&2
    exit 1
fi
if grep -q -- '--disable-ns-self-contained' "$repo_root/build_emacs30.sh"; then
    echo "the installed macOS app must be self-contained" >&2
    exit 1
fi
grep -q 'bin/emacs-macos-wrapper' "$repo_root/build_emacs30.sh"
grep -q 'emacs-app-path' "$repo_root/bin/emacs-macos-wrapper"
grep -q 'install -m 644.*emacs-app-path' "$repo_root/build_emacs30.sh"
wrapper_root="$tmp/wrapper"
mock_app="$tmp/Custom Emacs.app"
mkdir -p "$wrapper_root" "$mock_app/Contents/MacOS"
cp "$repo_root/bin/emacs-macos-wrapper" "$wrapper_root/emacs"
printf '%s\n' "$mock_app" > "$wrapper_root/emacs-app-path"
cat > "$mock_app/Contents/MacOS/Emacs" << 'EOF'
#!/bin/sh
printf 'mock-emacs:%s\n' "$*"
EOF
chmod +x "$wrapper_root/emacs" "$mock_app/Contents/MacOS/Emacs"
[[ "$("$wrapper_root"/emacs --batch smoke)" == 'mock-emacs:--batch smoke' ]]
grep -q 'brew trust --formula hashicorp/tap/terraform' "$repo_root/prereq_packages.sh"
grep -q 'brew trust --formula oven-sh/bun/bun' "$repo_root/prereq_packages.sh"
grep -q 'uv already installed; updates are managed by Homebrew' "$repo_root/prereq_packages.sh"
grep -q '^NODE_VERSION="26"$' "$repo_root/versions.conf"
grep -q 'normalized_remote#git@github.com:' "$repo_root/build_emacs30.sh"
grep -q '^SPACEMACS_BRANCH="working"$' "$repo_root/build_emacs30.sh"
grep -q '^SPACEMACS_FETCH_BRANCHES=(develop working)$' "$repo_root/build_emacs30.sh"
grep -q -- '--branch "$SPACEMACS_BRANCH" "$SPACEMACS_REPO"' "$repo_root/build_emacs30.sh"
grep -q 'remote\.\$remote_name\.fetch' "$repo_root/build_emacs30.sh"
grep -q -- '--branch working' "$repo_root/ci/macos-full-setup.sh"
grep -q 'refs/heads/develop:refs/remotes/origin/develop' "$repo_root/ci/macos-full-setup.sh"
[[ "$(grep -c 'prereq_packages.sh.*create_snippet_symlink' "$repo_root/build_emacs30.sh")" -ge 2 ]]
grep -q 'uv tool install --force ipython --with ipykernel' "$repo_root/prereq_packages.sh"
if grep -q 'uv tool install ipykernel' "$repo_root/prereq_packages.sh"; then
    echo "ipykernel must be injected into a tool environment, not installed as a standalone uv tool" >&2
    exit 1
fi
if grep -Eq '(^|[[:space:]])tac([[:space:]]|$)' "$repo_root/prereq_packages.sh"; then
    echo "prereq_packages.sh must not require GNU tac on macOS" >&2
    exit 1
fi

echo "macOS CI guard tests passed"
