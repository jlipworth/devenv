# AI notification backends

This directory contains the repo-managed notification shim used by:

- `Claude Code` via `~/.claude/settings.json`
- `Codex` via `~/.codex/config.toml`

The stable user-facing command is:

```bash
ai-notify-if-unfocused
```

`make ai-tools` installs that command as a symlink in:

```bash
~/.local/bin/ai-notify-if-unfocused
```

## Design

The top-level dispatcher:

- detects the current environment/terminal
- suppresses notifications when the terminal is frontmost
- selects a backend
- exits cleanly when no supported backend is available

Current backend mapping:

- macOS + Ghostty → `backends/ghostty-osc9.sh`
- macOS + Alacritty → `backends/macos-osascript.sh`
- WSL2 → `backends/wsl2-toast.sh`
- anything else → `backends/noop.sh`

Suppression behavior differs by platform:

- macOS suppression happens in the dispatcher using the current frontmost app.
- WSL2 suppression happens inside `backends/wsl2-toast.sh` by querying the
  Windows foreground process and suppressing when it is `alacritty.exe`.

## Debugging

Enable debug logs:

```bash
AI_NOTIFY_DEBUG=1 ai-notify-if-unfocused "test"
```

Force a specific backend:

```bash
AI_NOTIFY_BACKEND=macos-osascript ai-notify-if-unfocused "test"
AI_NOTIFY_BACKEND=ghostty-osc9 ai-notify-if-unfocused "test"
AI_NOTIFY_BACKEND=wsl2-toast ai-notify-if-unfocused "test"
```

## Notes

- Ghostty notifications use OSC 9 and stay terminal-native.
- The macOS fallback currently uses AppleScript notifications for reliability.
- The WSL2 backend is best-effort and should be validated on the Windows
  machine. It depends on `powershell.exe` being available from WSL.
- All notification logic is kept inside `~/GNU_files`.
