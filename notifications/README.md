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

- macOS + Ghostty → `backends/macos-osascript.sh`
- macOS + other terminals → `backends/macos-osascript.sh`
- WSL2 → `backends/wsl2-toast.sh`
- anything else → `backends/noop.sh`

Suppression behavior differs by platform:

- macOS suppression happens in the dispatcher for terminals that identify as Ghostty or Alacritty.
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

- Ghostty can be tested with `AI_NOTIFY_BACKEND=ghostty-osc9`, but the default
  macOS path asks Ghostty itself to post the notification via AppleScript so
  macOS uses Ghostty's sender icon, falling back to other native notifiers for
  non-Ghostty terminals.
- The WSL2 backend is best-effort and should be validated on the Windows
  machine. It depends on `powershell.exe` being available from WSL.
- All notification logic is kept inside this repo checkout.
