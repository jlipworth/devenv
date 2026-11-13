#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/rust-install-spec.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home"
cat >"$tmp/bin/uname" <<'EOF'
#!/usr/bin/env bash
printf 'Darwin\n'
EOF
cat >"$tmp/bin/brew" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$tmp/bin/rustup" <<'EOF'
#!/usr/bin/env bash
printf 'rustup %s\n' "$*" >>"$RUST_TEST_LOG"
if [ "$*" = "${RUST_TEST_FAIL_RUSTUP:-}" ]; then exit 7; fi
EOF
cat >"$tmp/bin/cargo" <<'EOF'
#!/usr/bin/env bash
printf 'cargo %s\n' "$*" >>"$RUST_TEST_LOG"
case "$*" in
    'install cargo-edit') exit "${RUST_TEST_FAIL_EDIT:-0}" ;;
  'install cargo-outdated --features vendored-openssl') exit "${RUST_TEST_FAIL_OUTDATED:-0}" ;;
  'outdated --version') exit "${RUST_TEST_MISSING_OUTDATED:-0}" ;;
  'upgrade --help') exit "${RUST_TEST_MISSING_EDIT:-0}" ;;
esac
EOF
chmod +x "$tmp/bin/"*

run_install() {
    HOME="$tmp/home" GNU_DIR="$repo_root" PATH="$tmp/bin:/usr/bin:/bin" \
        "$repo_root/prereq_packages.sh" install_rust_support >"$tmp/output" 2>&1
}

export RUST_TEST_LOG="$tmp/success.log"
run_install
grep -Fxq 'cargo install cargo-outdated --features vendored-openssl' "$RUST_TEST_LOG"
grep -Fxq 'cargo upgrade --help' "$RUST_TEST_LOG"
grep -Fxq 'cargo outdated --version' "$RUST_TEST_LOG"
grep -Fq 'Rust development environment setup complete' "$tmp/output"

# A failed compiler/component install must not continue into extensions.
for step in 'install stable' 'default stable' 'component add rust-analyzer' 'component add rustfmt' 'component add clippy'; do
    export RUST_TEST_LOG="$tmp/rustup-failure.log"
    : >"$RUST_TEST_LOG"
    if RUST_TEST_FAIL_RUSTUP="$step" run_install; then
        printf 'failed rustup step reported success: %s\n' "$step" >&2
        exit 1
    fi
    if grep -q '^cargo ' "$RUST_TEST_LOG"; then
        printf 'failed rustup step continued to Cargo extensions\n' >&2
        exit 1
    fi
done

for fault in RUST_TEST_FAIL_EDIT RUST_TEST_FAIL_OUTDATED RUST_TEST_MISSING_OUTDATED RUST_TEST_MISSING_EDIT; do
    export RUST_TEST_LOG="$tmp/$fault.log"
    if env "$fault=9" HOME="$tmp/home" GNU_DIR="$repo_root" PATH="$tmp/bin:/usr/bin:/bin" \
        "$repo_root/prereq_packages.sh" install_rust_support >"$tmp/output" 2>&1; then
        printf '%s was swallowed as successful Rust setup\n' "$fault" >&2
        exit 1
    fi
    if grep -Fq 'Rust development environment setup complete' "$tmp/output"; then
        printf '%s printed a false success\n' "$fault" >&2
        exit 1
    fi
done
printf 'Rust native dependency compatibility and required-tool failure checks passed\n'
