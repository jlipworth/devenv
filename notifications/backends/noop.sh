#!/usr/bin/env bash

set -euo pipefail

if [[ "${AI_NOTIFY_DEBUG:-0}" == "1" ]]; then
    printf '[ai-notify] notifier=noop\n' >&2
fi

exit 0
