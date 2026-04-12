#!/usr/bin/env bash
# Run each *_spec.lua file under this directory via nvim --headless and aggregate results.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVIM_CONFIG="${HERE}/../../nvim"

fail=0
for spec in "${HERE}"/*_spec.lua; do
    echo "=== Running: $(basename "$spec") ==="
    if ! NVIM_APPNAME=_jupyter_test_dummy nvim --headless \
        --cmd "set runtimepath^=${NVIM_CONFIG}" \
        -u NONE \
        -c "luafile ${spec}" \
        -c "qall!"; then
        fail=1
    fi
done
exit "$fail"
