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

- SSH session with relay socket → `backends/remote-relay.sh`
- macOS + Ghostty → `backends/macos-osascript.sh`
- macOS + other terminals → `backends/macos-osascript.sh`
- WSL2 → `backends/wsl2-toast.sh`
- anything else → `backends/noop.sh`

Suppression behavior differs by platform:

- macOS suppression happens in the dispatcher for terminals that identify as Ghostty or Alacritty.
- WSL2 suppression happens inside `backends/wsl2-toast.sh` by querying the
  Windows foreground process and suppressing when it is `alacritty.exe`.
- SSH relay suppression happens on the local Mac after the forwarded message
  arrives, so it can still check the actual frontmost app.

## Remote SSH notifications

Ghostty documents OSC 9 as a desktop-notification sequence, and Ghostty 1.2.0
release notes recommend avoiding the `OSC 9;4` progress-report collision (the
`ghostty-osc9` test backend already prefixes messages that would collide).
In practice, raw OSC notifications emitted on `jumpbox01` over SSH have not
reliably surfaced as macOS desktop notifications in this setup.

The repo therefore includes a **foreground-only** local relay reached through
OpenSSH Unix-socket forwarding.  It is intentionally not installed as a daemon
and does not keep Python resident.  Start it only for an SSH work session and
stop it with `Ctrl-C` when done.

Topology while the relay is running:

```text
Codex/Claude on jumpbox01
  -> ai-notify-if-unfocused
  -> ~/.cache/ai-notify/relay.sock on jumpbox01
  -> SSH RemoteForward
  -> ~/.cache/ai-notify/relay.sock on the Mac
  -> foreground ai-notify-relay-local
  -> macOS notification backend
```

### 1. Install repo helper symlinks

On the Mac checkout:

```bash
make ai-tools
```

This only symlinks repo-managed helpers into `~/.local/bin`; it does not create
a LaunchAgent or background service.

### 2. Start the local relay only when needed

On the Mac, in a terminal you are willing to leave open during the SSH work
session:

```bash
AI_NOTIFY_DEBUG=1 ai-notify-relay-local
```

It listens on:

```bash
~/.cache/ai-notify/relay.sock
```

Stop it with `Ctrl-C`.

### 3. Forward the relay socket when SSHing to jumpbox01

Add a host-specific `RemoteForward` on the Mac.  Replace the two absolute home
paths if they differ:

```sshconfig
Host jumpbox01
  StreamLocalBindUnlink yes
  RemoteForward /home/malaka/.cache/ai-notify/relay.sock /Users/malaka/.cache/ai-notify/relay.sock
  SendEnv AI_NOTIFY_TERMINAL_NAME TERM_PROGRAM
```

Before connecting, ensure the remote parent exists at least once:

```bash
ssh jumpbox01 'mkdir -p ~/.cache/ai-notify'
```

If the Mac username is not `malaka`, use:

```bash
echo "$HOME/.cache/ai-notify/relay.sock"
```

on the Mac and put that exact path on the right-hand side of `RemoteForward`.

### 4. Preserve terminal identity

For frontmost-terminal suppression and Ghostty/Alacritty sender hints, export a
terminal name before SSH if your client does not already send one:

```bash
export AI_NOTIFY_TERMINAL_NAME=ghostty
```

or:

```bash
export AI_NOTIFY_TERMINAL_NAME=alacritty
```

### 5. Test from jumpbox01

Inside the SSH session:

```bash
AI_NOTIFY_DEBUG=1 ai-notify-if-unfocused "SSH relay test"
```

Expected debug shape:

```text
[ai-notify] terminal=ghostty
[ai-notify] backend=remote-relay
```

The notification appears only when Ghostty/Alacritty is not the frontmost app.
Focus another app before running the test if you want a visible banner.

## Debugging

Enable debug logs:

```bash
AI_NOTIFY_DEBUG=1 ai-notify-if-unfocused "test"
```

Force a specific backend:

```bash
AI_NOTIFY_BACKEND=macos-osascript ai-notify-if-unfocused "test"
AI_NOTIFY_BACKEND=ghostty-osc9 ai-notify-if-unfocused "test"
AI_NOTIFY_BACKEND=remote-relay ai-notify-if-unfocused "test"
AI_NOTIFY_BACKEND=wsl2-toast ai-notify-if-unfocused "test"
```

## Notes

- Ghostty can be tested with `AI_NOTIFY_BACKEND=ghostty-osc9`, but the default
  macOS path asks Ghostty itself to post the notification via AppleScript so
  macOS uses Ghostty's sender icon, falling back to other native notifiers for
  non-Ghostty terminals.
- The WSL2 backend is best-effort and should be validated on the Windows
  machine. It depends on `powershell.exe` being available from WSL.
- Remote SSH notifications intentionally prefer the relay backend when a
  forwarded socket is present. If the socket is absent, Linux/remote sessions
  still fall back to `noop` rather than blocking task completion.
- All notification logic is kept inside this repo checkout.
