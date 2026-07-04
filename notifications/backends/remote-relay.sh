#!/usr/bin/env bash

set -euo pipefail

debug_log() {
    if [[ "${AI_NOTIFY_DEBUG:-0}" == "1" ]]; then
        printf '[ai-notify] %s\n' "$*" >&2
    fi
}

socket_path="${AI_NOTIFY_RELAY_SOCKET:-$HOME/.cache/ai-notify/relay.sock}"

if [[ ! -S "$socket_path" ]]; then
    debug_log "remote relay socket not available: $socket_path"
    exit 0
fi

if ! command -v nc > /dev/null 2>&1; then
    debug_log "remote relay skipped: nc missing"
    exit 0
fi

b64() {
    if base64 --help 2>&1 | grep -q -- '-w'; then
        printf '%s' "$1" | base64 -w 0
    else
        printf '%s' "$1" | base64 | tr -d '\n'
    fi
}

title="${AI_NOTIFY_TITLE:-Task finished}"
body="${AI_NOTIFY_BODY:-A background task completed.}"
terminal="${AI_NOTIFY_TERMINAL_NAME:-}"

{
    printf 'ai-notify-v1\n'
    printf 'terminal=%s\n' "$(b64 "$terminal")"
    printf 'title=%s\n' "$(b64 "$title")"
    printf 'body=%s\n' "$(b64 "$body")"
} | nc -U -w 1 "$socket_path" > /dev/null 2>&1 || true
