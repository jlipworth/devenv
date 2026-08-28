#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/ai-tools-spec.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

# A standalone target must activate nvm even when a system npm is already on
# PATH. This reproduces the condition that originally installed OpenCode under
# /opt/homebrew instead of the configured nvm environment.
home="$tmp/nvm-home"
system_bin="$tmp/system-bin"
nvm_bin="$home/.nvm/versions/node/v26.7.0/bin"
mkdir -p "$system_bin" "$nvm_bin" "$home/.nvm"

cat > "$system_bin/brew" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$system_bin/brew"

for tool in node npm; do
    cat > "$system_bin/$tool" << EOF
#!/usr/bin/env bash
printf 'system-$tool\n'
EOF
    cat > "$nvm_bin/$tool" << EOF
#!/usr/bin/env bash
printf 'nvm-$tool\n'
EOF
    chmod +x "$system_bin/$tool" "$nvm_bin/$tool"
done

cat > "$home/.nvm/nvm.sh" << EOF
nvm() {
    if [[ "\${1:-}" == use ]]; then
        export NVM_BIN="$nvm_bin"
        export PATH="\$NVM_BIN:\$PATH"
    fi
}
EOF

env -u NVM_BIN -u NVM_DIR HOME="$home" GNU_DIR="$repo_root" \
    PATH="$system_bin:/usr/bin:/bin" \
    bash -c 'source "$GNU_DIR/common_utils.sh"; [[ "$(npm)" == nvm-npm ]]; [[ "$(node)" == nvm-node ]]'

# OpenCode must not regress into the generic npm package list, and the macOS
# installation must use the reviewed upstream tap.
if grep -Eq 'ai_packages=.*opencode-ai' "$repo_root/prereq_packages.sh"; then
    echo "OpenCode must not be installed by the generic npm AI package loop" >&2
    exit 1
fi
grep -q 'install_opencode' "$repo_root/prereq_packages.sh"
grep -q '^tap "anomalyco/tap"$' "$repo_root/brewfiles/Brewfile.ai_tools"
grep -q '^brew "anomalyco/tap/opencode"$' "$repo_root/brewfiles/Brewfile.ai_tools"
grep -q 'brew trust --formula anomalyco/tap/opencode' "$repo_root/prereq_packages.sh"
grep -q 'https://opencode.ai/install' "$repo_root/prereq_packages.sh"

# Exercise the macOS migration path with package managers mocked: remove the
# legacy npm package first, then install the tap-owned formula. The curl mock
# ensures the Linux-native path is not selected on macOS.
install_bin="$tmp/install-bin"
legacy_prefix="$tmp/legacy-prefix"
install_log="$tmp/install.log"
mkdir -p "$install_bin" "$legacy_prefix/lib/node_modules/opencode-ai"

cat > "$install_bin/node" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$install_bin/npm" << EOF
#!/usr/bin/env bash
printf 'npm %s\n' "\$*" >> "$install_log"
EOF
cat > "$install_bin/brew" << EOF
#!/usr/bin/env bash
printf 'brew %s\n' "\$*" >> "$install_log"
exit 0
EOF
cat > "$install_bin/uname" << 'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-s" || $# -eq 0 ]]; then
    printf 'Darwin\n'
else
    /usr/bin/uname "$@"
fi
EOF
cat > "$install_bin/curl" << 'EOF'
#!/usr/bin/env bash
echo "curl must not install OpenCode on macOS" >&2
exit 99
EOF
chmod +x "$install_bin"/*

env -u NVM_BIN -u NVM_DIR HOME="$tmp/install-home" GNU_DIR="$repo_root" \
    OPENCODE_LEGACY_NPM_PREFIX="$legacy_prefix" \
    PATH="$install_bin:/usr/bin:/bin" \
    "$repo_root/prereq_packages.sh" install_opencode > "$tmp/install-output.log"

grep -Fq "npm uninstall -g --prefix $legacy_prefix opencode-ai" "$install_log"
grep -Fq 'brew tap anomalyco/tap' "$install_log"
grep -Fq 'brew trust --formula anomalyco/tap/opencode' "$install_log"
grep -Fq "brew bundle --file=$repo_root/brewfiles/Brewfile.ai_tools" "$install_log"

echo "AI tools installation tests passed"
