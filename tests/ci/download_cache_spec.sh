#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/download-cache-spec.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

# Two clean installations share archives but never installed tools or sources.
for run in first second; do
    mkdir -p "$tmp/$run"
    (
        export HOME="$tmp/$run"
        # shellcheck source=ci/macos-download-cache.sh
        source "$repo_root/ci/macos-download-cache.sh"
        macos_ci_download_cache "$tmp/downloads"
        macos_ci_download_cache "$tmp/downloads"
        [[ "$CARGO_HOME" == "$HOME/.cargo" && "$OPAMROOT" == "$HOME/.opam" ]]
        if [[ "$run" == first ]]; then
            printf archive > "$HOME/.cargo/registry/cache/crate"
            printf archive > "$HOME/.opam/download-cache/package"
            printf archive > "$npm_config_cache/package"
            mkdir -p "$HOME/.cargo/bin" "$HOME/.cargo/registry/src" "$HOME/.opam/default"
        else
            [[ "$(cat "$HOME/.cargo/registry/cache/crate")" == archive ]]
            [[ "$(cat "$HOME/.opam/download-cache/package")" == archive ]]
            [[ "$(cat "$npm_config_cache/package")" == archive ]]
            [[ ! -e "$HOME/.cargo/bin" && ! -e "$HOME/.cargo/registry/src" ]]
            [[ ! -e "$HOME/.opam/default" ]]
        fi
    )
    rm -rf "$tmp/$run"
done
[[ -f "$tmp/downloads/cargo-archives/crate" ]]

echo "Download cache isolation passed"
