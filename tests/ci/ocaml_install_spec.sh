#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/ocaml-install-spec.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home"
cat > "$tmp/bin/brew" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$tmp/bin/opam" << 'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$OPAM_TEST_LOG"
case "$1 $2" in
    'var root') [[ -e "$HOME/initialized" ]] ;;
    'switch show') [[ -e "$HOME/switch" ]] ;;
    'switch create') touch "$HOME/switch" ;;
    'init --bare') touch "$HOME/initialized" ;;
    'env ') printf ':' ;;
esac
EOF
chmod +x "$tmp/bin/"*

for run in first second; do
    export OPAM_TEST_LOG="$tmp/$run.log"
    HOME="$tmp/home" GNU_DIR="$repo_root" PATH="$tmp/bin:/usr/bin:/bin" \
        "$repo_root/prereq_packages.sh" install_ocaml_support > "$tmp/$run.output"
done
cat > "$tmp/expected-first" << 'EOF'
var root
init --bare --disable-sandboxing -a -y
switch show
switch create default --empty -y
install -y ocaml-base-compiler ocp-indent merlin utop ocamlformat ocaml-lsp-server
env
EOF
diff -u "$tmp/expected-first" "$tmp/first.log"
cat > "$tmp/expected-second" << 'EOF'
var root
switch show
update
upgrade -y
install -y ocp-indent merlin utop ocamlformat ocaml-lsp-server
env
EOF
diff -u "$tmp/expected-second" "$tmp/second.log"
echo "OCaml single-solve installation passed"
