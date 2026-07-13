# Claude Code with GPT-5.6 Sol (`claugpt`)

`claugpt` keeps the Claude Code interface and agent harness while sending model
requests to GPT-5.6 Sol through CLIProxyAPI and OpenAI Codex OAuth.

```text
Claude Code -> Anthropic Messages API -> CLIProxyAPI -> Codex OAuth -> GPT-5.6 Sol
```

## Install on another Mac

Prerequisites:

- Homebrew
- Claude Code (`claude` must be on `PATH`)
- `jq`
- An OpenAI account with Codex access to `gpt-5.6-sol`

From this repository, run:

```bash
bin/setup-claugpt
```

The script is idempotent. It:

1. Installs CLIProxyAPI with Homebrew when necessary.
2. Creates a random localhost-only proxy key.
3. Configures standard `gpt-5.6-sol` routing and an explicit priority alias.
4. Performs Codex OAuth when no existing CLIProxyAPI credential is present.
5. Installs the `claugpt`, `claudgpy`, and `claugptf` launchers.
6. Starts CLIProxyAPI as a Homebrew service and verifies both model names.

Existing unmanaged CLIProxyAPI configuration is timestamp-backed-up before the
script replaces it. OAuth credentials and local proxy keys are never stored in
this repository.

## Usage

```bash
cd /path/to/project
claugpt
```

Claude Code does not enumerate arbitrary proxy model names in `/model`, so its
built-in slots are mapped as follows:

| Claude Code selection | Actual route |
| --- | --- |
| `/model opus` | `gpt-5.6-sol` (standard) |
| `/model sonnet` | `gpt-5.6-sol` (standard) |
| `/model haiku` | `gpt-5.6-sol` (standard) |

Reasoning effort is independent of the service tier and can be changed using
Claude Code's native command:

```text
/effort low
/effort medium
/effort high
/effort xhigh
/effort auto
```

CLIProxyAPI translates Claude's `output_config.effort` into OpenAI's
`reasoning.effort`. The fast/priority alias is deliberately absent from every
Claude model slot and subagent setting, so Haiku and background agents remain
on standard GPT-5.6 Sol.

All three launchers set `CLAUDE_CODE_MAX_CONTEXT_TOKENS=258400`. This matches the
effective Codex window for GPT-5.6 Sol (272,000 raw tokens at 95%) and applies
only to processes launched through `claugpt` or `claudgpy`; normal `claude`
sessions retain Claude Code's standard model-specific context settings.

The launchers also match the tested Claude Code gateway setup by setting:

```text
CLAUDE_CODE_SUBAGENT_MODEL=gpt-5.6-sol
CLAUDE_CODE_ALWAYS_ENABLE_EFFORT=1
CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY=3
ENABLE_TOOL_SEARCH=false
```

This keeps spawned subagents on GPT-5.6 Sol, exposes effort controls, limits
parallel read-only tool/subagent work to three, and loads MCP tools up front
instead of relying on proxy support for deferred `tool_reference` blocks.

## Permission modes

Permission handling remains entirely inside the Claude Code harness, so every
Claude Code permission mode also works with GPT through `claugpt`:

```bash
# Manual: prompt when an action is not already allowed (the default)
claugpt

# Auto: let Claude Code's safety classifier approve routine actions and stop or
# prompt for operations it judges risky
claugpt --permission-mode auto

# YOLO: bypass all permission prompts and checks
claugpt --dangerously-skip-permissions

# Standard model with YOLO mode enabled by default
claudgpy

# Priority-tier main model with YOLO mode enabled by default
claugptf
```

YOLO mode is appropriate only in a trusted repository or, preferably, an
isolated sandbox: it permits model-generated shell commands and file changes
without review. The setup script deliberately leaves manual mode as the default
for `claugpt`. The explicitly named `claudgpy` launcher enables YOLO mode on the
standard model. `claugptf` is the only generated launcher that opts the main
session into the `gpt-5.6-sol-fast` priority alias, and it always enables YOLO
mode. Its spawned subagents still use standard `gpt-5.6-sol`.

## Files created outside the repository

```text
~/.local/bin/claugpt
~/.local/bin/claudgpy
~/.local/bin/claugptf
~/.cli-proxy-api/claugpt-key
~/.cli-proxy-api/codex-*.json
$(brew --prefix)/etc/cliproxyapi.conf
```

## Operations and troubleshooting

```bash
brew services info cliproxyapi
brew services restart cliproxyapi

KEY="$(cat ~/.cli-proxy-api/claugpt-key)"
curl -fsS -H "Authorization: Bearer ${KEY}" \
  http://127.0.0.1:8317/v1/models | jq -r '.data[]?.id'
```

Re-run OAuth if required:

```bash
cliproxyapi -codex-login
```
