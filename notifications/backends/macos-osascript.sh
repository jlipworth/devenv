#!/usr/bin/env bash

set -euo pipefail

debug_log() {
    if [[ "${AI_NOTIFY_DEBUG:-0}" == "1" ]]; then
        printf '[ai-notify] %s\n' "$*" >&2
    fi
}

[[ "$(uname -s)" == "Darwin" ]] || exit 0
command -v osascript > /dev/null 2>&1 || exit 0

export NOTIFY_TITLE="${AI_NOTIFY_TITLE:-Task finished}"
export NOTIFY_BODY="${AI_NOTIFY_BODY:-A background task completed.}"

debug_log "notifier=osascript"
osascript -e 'display notification (system attribute "NOTIFY_BODY") with title (system attribute "NOTIFY_TITLE")' > /dev/null 2>&1 || true
