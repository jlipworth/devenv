#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/ocaml-install-spec.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home"
cat >"$tmp/bin/brew" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$tmp/bin/opam" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$OPAM_TEST_LOG"
case "$1 $2" in
    'var root') [[ -e "$HOME/initialized" ]] ;;
    'switch show') [[ -e "$HOME/switch" ]] ;;
    'switch create') touch "$HOME/switch" ;;
    'init --bare') touch "$HOME/initialized" ;;
    'env ') printf ':' ;;
    'install -y') exit "${OPAM_TEST_FAIL_INSTALL:-0}" ;;
esac
EOF
chmod +x "$tmp/bin/"*

for run in first second; do
  export OPAM_TEST_LOG="$tmp/$run.log"
  HOME="$tmp/home" GNU_DIR="$repo_root" PATH="$tmp/bin:/usr/bin:/bin" \
    "$repo_root/prereq_packages.sh" install_ocaml_support >"$tmp/$run.output"
done
cat >"$tmp/expected-first" <<'EOF'
var root
init --bare --disable-sandboxing -a -y
switch show
switch create default --empty -y
install -y ocaml-base-compiler.5.4.1 dune.3.22.2 stdune.3.22.2 ocp-indent.1.10.0 merlin.5.7.1-504 utop.2.18.0 ocamlformat.0.29.0 ocaml-lsp-server.1.26.1
env
EOF
diff -u "$tmp/expected-first" "$tmp/first.log"
cat >"$tmp/expected-second" <<'EOF'
var root
switch show
update
install -y ocaml-base-compiler.5.4.1 dune.3.22.2 stdune.3.22.2 ocp-indent.1.10.0 merlin.5.7.1-504 utop.2.18.0 ocamlformat.0.29.0 ocaml-lsp-server.1.26.1
env
EOF
diff -u "$tmp/expected-second" "$tmp/second.log"

# A failed constrained install must stop before shell activation/success.
export OPAM_TEST_LOG="$tmp/failure.log"
if HOME="$tmp/home" GNU_DIR="$repo_root" PATH="$tmp/bin:/usr/bin:/bin" OPAM_TEST_FAIL_INSTALL=7 \
  "$repo_root/prereq_packages.sh" install_ocaml_support >"$tmp/failure.output"; then
  echo "failed opam install unexpectedly succeeded" >&2
  exit 1
fi
if grep -Fxq env "$tmp/failure.log" || grep -Fq 'OCaml support installed successfully' "$tmp/failure.output"; then
  echo "failed opam install activated or reported success" >&2
  exit 1
fi
echo "OCaml constrained single-solve installation and failure handling passed"
