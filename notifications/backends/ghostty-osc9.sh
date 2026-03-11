#!/usr/bin/env bash

set -euo pipefail

debug_log() {
    if [[ "${AI_NOTIFY_DEBUG:-0}" == "1" ]]; then
        printf '[ai-notify] %s\n' "$*" >&2
    fi
}

lower() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

ghostty_hint="${AI_NOTIFY_TERMINAL:-}"
ghostty_hint="$(printf '%s' "$ghostty_hint" | tr '[:upper:]' '[:lower:]')"

if [[ -z "${GHOSTTY_RESOURCES_DIR:-}" && -z "${GHOSTTY_BIN_DIR:-}" && "$ghostty_hint" != "ghostty" ]]; then
    debug_log "ghostty backend skipped: ghostty environment not detected"
    exit 0
fi

title="${AI_NOTIFY_TITLE:-Task finished}"
body="${AI_NOTIFY_BODY:-}"

message="$title"
if [[ -n "$body" && "$body" != "$title" ]]; then
    message="$title: $body"
fi

# Avoid the Ghostty OSC 9;4 progress-bar ambiguity.
case "$message" in
    4\;*) message="Notification: $message" ;;
esac

debug_log "notifier=ghostty-osc9 message=$message"

if [[ -n "${TMUX:-}" ]]; then
    # tmux passthrough wrapper. Requires `set -g allow-passthrough on`.
    # Use BEL for the inner OSC terminator to keep the wrapped form simple.
    debug_log "ghostty-osc9 using tmux passthrough"
    printf '\033Ptmux;\033\033]9;%s\a\033\\' "$message" > /dev/tty 2> /dev/null || true
elif [[ -n "${SSH_CONNECTION:-}" ]]; then
    remote_term="$(lower "${TERM:-}")"
    case "$remote_term" in
        screen* | tmux*)
            debug_log "ghostty-osc9 using ssh tmux passthrough"
            printf '\033Ptmux;\033\033]9;%s\a\033\\' "$message" > /dev/tty 2> /dev/null || true
            ;;
        *)
            printf '\033]9;%s\033\\' "$message" > /dev/tty 2> /dev/null || true
            ;;
    esac
else
    printf '\033]9;%s\033\\' "$message" > /dev/tty 2> /dev/null || true
fi
