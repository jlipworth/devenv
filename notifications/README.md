# Legacy AI notification helpers (retired)

Codex and Claude Code now use their native terminal notifications. The scripts
in this directory are retained only as historical reference; `make ai-tools`
no longer installs or invokes them.

To migrate an existing checkout after pulling the latest repo changes:

```bash
make ai-notifications-native
```

This removes only the repo's custom Codex `notify` command and Claude Code
`Stop` notification hook, enables Codex TUI notifications when unfocused, sets
Claude Code's notification channel to `auto` if it was disabled, and removes
legacy helper symlinks from `~/.local/bin`. Other hooks and local settings are
preserved. The Codex app's computer-use notification wrapper, if present, is
retained with its former custom notification payload cleared.

For SSH sessions, native notification delivery depends on the terminal and
remote-session support. The old SSH relay is no longer configured by this repo.
Remove any `LocalCommand ...ai-notify-relay-ensure-macos` and
`RemoteForward 127.0.0.1:31997 ...ai-notify...` lines from your SSH config if
you added them for the retired relay.
