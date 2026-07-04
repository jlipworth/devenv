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

if ! command -v python3 > /dev/null 2>&1; then
    debug_log "remote relay skipped: python3 missing"
    exit 0
fi

export AI_NOTIFY_RELAY_SOCKET_PATH="$socket_path"
python3 - << 'PY' || true
import json
import os
import socket

socket_path = os.environ.get("AI_NOTIFY_RELAY_SOCKET_PATH", "")
message = {
    "title": os.environ.get("AI_NOTIFY_TITLE", "Task finished"),
    "body": os.environ.get("AI_NOTIFY_BODY", "A background task completed."),
    "terminal": os.environ.get("AI_NOTIFY_TERMINAL_NAME", ""),
}

with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
    client.settimeout(1.5)
    client.connect(socket_path)
    client.sendall(json.dumps(message, ensure_ascii=False).encode("utf-8") + b"\n")
PY
