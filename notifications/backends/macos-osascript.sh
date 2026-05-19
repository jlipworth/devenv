#!/usr/bin/env bash

set -euo pipefail

debug_log() {
    if [[ "${AI_NOTIFY_DEBUG:-0}" == "1" ]]; then
        printf '[ai-notify] %s\n' "$*" >&2
    fi
}

[[ "$(uname -s)" == "Darwin" ]] || exit 0

export NOTIFY_TITLE="${AI_NOTIFY_TITLE:-Task finished}"
export NOTIFY_BODY="${AI_NOTIFY_BODY:-A background task completed.}"

terminal_bundle_id() {
    case "${AI_NOTIFY_TERMINAL_NAME:-}" in
        ghostty) printf 'com.mitchellh.ghostty' ;;
        alacritty) printf 'org.alacritty' ;;
        *) return 1 ;;
    esac
}

terminal_icon_url() {
    case "${AI_NOTIFY_TERMINAL_NAME:-}" in
        ghostty)
            if [[ -f /Applications/Ghostty.app/Contents/Resources/Ghostty.icns ]]; then
                printf 'file:///Applications/Ghostty.app/Contents/Resources/Ghostty.icns'
            else
                return 1
            fi
            ;;
        *) return 1 ;;
    esac
}

if [[ "${AI_NOTIFY_TERMINAL_NAME:-}" == "ghostty" ]] && command -v osascript > /dev/null 2>&1; then
    debug_log "notifier=osascript-app sender=com.mitchellh.ghostty"
    osascript > /dev/null 2>&1 << 'APPLESCRIPT' || true
tell application id "com.mitchellh.ghostty"
  display notification (system attribute "NOTIFY_BODY") with title (system attribute "NOTIFY_TITLE")
end tell
APPLESCRIPT
    exit 0
fi

if command -v terminal-notifier > /dev/null 2>&1; then
    args=(
        -title "$NOTIFY_TITLE"
        -message "$NOTIFY_BODY"
        -group "ai-notify-if-unfocused"
    )
    bundle_id=""
    icon_url=""
    if bundle_id="$(terminal_bundle_id 2> /dev/null)"; then
        args+=(-activate "$bundle_id")
    fi
    if icon_url="$(terminal_icon_url 2> /dev/null)"; then
        args+=(-appIcon "$icon_url")
    fi
    debug_log "notifier=terminal-notifier activate=${bundle_id:-default} appIcon=${icon_url:-default}"
    terminal-notifier "${args[@]}" > /dev/null 2>&1 || true
    exit 0
fi

command -v osascript > /dev/null 2>&1 || exit 0

debug_log "notifier=osascript"
osascript -e 'display notification (system attribute "NOTIFY_BODY") with title (system attribute "NOTIFY_TITLE")' > /dev/null 2>&1 || true
