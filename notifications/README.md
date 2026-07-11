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
- suppresses its CLI notification hook inside the Codex desktop app (including
  sub-agent completions), leaving desktop notification policy to the app
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

- The Codex macOS desktop app is always suppressed. The app and standalone CLI
  share `~/.codex/config.toml`, but this notification shim is intended for CLI
  terminal sessions only.
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

The repo therefore includes a lightweight local relay reached through OpenSSH
forwarding. It is intentionally not installed as a daemon and does not keep
Python resident. For `jumpbox01`, SSH can auto-start it on demand with an idle
timeout; manual foreground debugging is still available when needed.

Once the relay is available and the SSH connection has the `RemoteForward`, any
Codex/Claude/task hook on the remote host that calls `ai-notify-if-unfocused`
will automatically use `backends/remote-relay.sh`. No per-agent configuration is
needed beyond making sure the remote checkout is installed with `make ai-tools`.
The recommended `jumpbox01` setup uses a remote localhost TCP forward instead of
a remote Unix socket, so there is no remote socket file to clean up after the
SSH session ends.

Topology while the relay is running:

```text
Codex/Claude on jumpbox01
  -> ai-notify-if-unfocused
  -> 127.0.0.1:31997 on jumpbox01
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

### 2. Let SSH auto-start the local relay

For `jumpbox01`, the Mac SSH config can start the local relay automatically with
`LocalCommand`. The helper is single-instance: if a relay is already listening it
exits immediately; otherwise it starts `ai-notify-relay-local` in the background
with an idle timeout.

Add a host-specific block on the Mac. Replace the local socket path if your Mac
home directory differs:

```sshconfig
Host jumpbox01
  HostName jumpbox01.home.crapmaster.org
  User malaka
  PermitLocalCommand yes
  LocalCommand /Users/jlipworth/.local/bin/ai-notify-relay-ensure-macos
  RemoteForward 127.0.0.1:31997 /Users/jlipworth/.cache/ai-notify/relay.sock
  SetEnv TERM=xterm-256color
  SendEnv AI_NOTIFY_TERMINAL_NAME TERM_PROGRAM
```

This means normal `ssh jumpbox01` is enough. The remote helper probes the
conventional remote-local listener at `127.0.0.1:31997`, and SSH carries matching
notification traffic back to the Mac relay socket.

For future Macs, the right-hand side of `RemoteForward` must be that Mac user's
local relay socket. Check it with:

```bash
echo "$HOME/.cache/ai-notify/relay.sock"
```

Manual foreground debugging still works if you want to watch relay decisions:

```bash
AI_NOTIFY_DEBUG=1 ai-notify-relay-local
```

### 3. Preserve terminal identity

For frontmost-terminal suppression and Ghostty/Alacritty sender hints, export a
terminal name before SSH if your client does not already send one:

```bash
export AI_NOTIFY_TERMINAL_NAME=ghostty
```

or:

```bash
export AI_NOTIFY_TERMINAL_NAME=alacritty
```

### 4. Test from jumpbox01

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
