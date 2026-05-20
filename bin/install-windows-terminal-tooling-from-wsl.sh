#!/usr/bin/env bash
set -euo pipefail

# Run the Windows-side psmux + Alacritty installer from WSL2.
# Usage:
#   ./bin/install-windows-terminal-tooling-from-wsl.sh [extra PowerShell args]
# Example:
#   ./bin/install-windows-terminal-tooling-from-wsl.sh -SkipFonts

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "$script_dir/.." && pwd)"

if ! grep -qi microsoft /proc/version 2> /dev/null; then
    echo "warning: this launcher is intended for WSL2; continuing anyway" >&2
fi

if ! command -v powershell.exe > /dev/null 2>&1; then
    echo "error: powershell.exe not found on PATH; this must be run from WSL with Windows interop enabled" >&2
    exit 1
fi

if ! command -v wslpath > /dev/null 2>&1; then
    echo "error: wslpath not found; cannot translate repo path for Windows" >&2
    exit 1
fi

windows_script_path="$(wslpath -w "$repo_dir/install-windows-terminal-tooling.ps1")"
windows_repo_path="$(wslpath -w "$repo_dir")"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$windows_script_path" -GnuFilesPath "$windows_repo_path" "$@"
