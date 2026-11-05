#!/usr/bin/env bash
# Reuse downloaded archives, never installed packages or compiler outputs.
macos_ci_download_cache() {
    local cache_root="$1"
    mkdir -p "$cache_root"
    cache_root="$(cd "$cache_root" && pwd -P)"
    export npm_config_cache="$cache_root/npm"
    export NPM_CONFIG_CACHE="$npm_config_cache"
    export CARGO_HOME="$HOME/.cargo"
    export OPAMROOT="$HOME/.opam"
    mkdir -p "$npm_config_cache" "$cache_root/cargo-archives" \
        "$cache_root/cargo-git" "$cache_root/opam" \
        "$HOME/.cargo/registry" "$HOME/.cargo/git" "$HOME/.opam"
    macos_ci_cache_link "$cache_root/cargo-archives" "$CARGO_HOME/registry/cache"
    macos_ci_cache_link "$cache_root/cargo-git" "$CARGO_HOME/git/db"
    macos_ci_cache_link "$cache_root/opam" "$OPAMROOT/download-cache"
}

macos_ci_cache_link() {
    if [[ -L "$2" && "$(readlink "$2")" == "$1" ]]; then
        return 0
    fi
    # Fail if an unexpected cache already exists; never overwrite user data.
    if [[ -e "$2" || -L "$2" ]]; then
        printf 'Unexpected existing download cache: %s\n' "$2" >&2
        return 1
    fi
    ln -s "$1" "$2"
}
