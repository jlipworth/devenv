#!/usr/bin/env bash
# Run each *_spec.lua file under this directory via nvim --headless and aggregate results.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVIM_CONFIG="${HERE}/../../nvim"

fail=0
for spec in "${HERE}"/*_spec.lua; do
    echo "=== Running: $(basename "$spec") ==="
    # A bare `luafile` error does not change nvim's exit status, so catch it
    # and exit non-zero ourselves.
    if ! SPEC="$spec" NVIM_APPNAME=_jupyter_test_dummy nvim --headless \
        --cmd "set runtimepath^=${NVIM_CONFIG}" \
        -u NONE \
        -c "lua local ok, err = pcall(dofile, os.getenv('SPEC')); if not ok then io.stderr:write(tostring(err) .. '\n'); vim.cmd('cq! 1') end" \
        -c "qall!"; then
        fail=1
    fi
done
exit "$fail"
