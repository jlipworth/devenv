#!/usr/bin/env python3
"""Post one Discord message with the pipeline's overall result.

A Woodpecker step's `when.status` only sees its own workflow, so the notify
workflow cannot tell from inside Woodpecker whether build or layers failed.
Woodpecker reports each workflow to GitHub as a commit status, and the repo is
public, so read those instead.
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request

WORKFLOWS = ("build", "layers", "lint", "noadmin")
REPO = "jlipworth/devenv"


def latest_states(sha: str, event: str) -> dict[str, str]:
    prefix = f"ci/woodpecker/{'pr' if event == 'pull_request' else event}/"
    url = f"https://api.github.com/repos/{REPO}/commits/{sha}/statuses?per_page=100"
    request = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(request, timeout=20) as response:
        statuses = json.load(response)
    states: dict[str, str] = {}
    for status in statuses:  # newest first
        name = status["context"].removeprefix(prefix)
        if status["context"].startswith(prefix) and name in WORKFLOWS:
            states.setdefault(name, status["state"])
    return states


def pipeline_result(sha: str, event: str) -> tuple[str, list[str]]:
    """Return ("success" | "failure" | "unknown", failed workflow names)."""
    states: dict[str, str] = {}
    for _ in range(12):
        try:
            states = latest_states(sha, event)
        except (OSError, urllib.error.URLError, ValueError) as error:
            print(f"could not read commit statuses: {error}", file=sys.stderr)
            return "unknown", []
        # The last dependency's status can land just after this workflow starts.
        if "pending" not in states.values():
            break
        time.sleep(10)
    failed = sorted(name for name, state in states.items() if state in ("failure", "error"))
    if failed:
        return "failure", failed
    if "lint" not in states or "pending" in states.values():
        return "unknown", []
    return "success", []


def main() -> int:
    env = os.environ
    result, failed = pipeline_result(env["CI_COMMIT_SHA"], env["CI_PIPELINE_EVENT"])
    headline = {
        "success": "✅ **Success**",
        "failure": f"❌ **Failed** ({', '.join(failed)})",
        "unknown": "⚠️ **Finished, result unknown**",
    }[result]
    message = (
        f"{headline}: {env.get('CI_REPO_NAME', REPO)} ({env.get('CI_COMMIT_BRANCH', '')})\n"
        f"{env.get('CI_COMMIT_MESSAGE', '').splitlines()[0] if env.get('CI_COMMIT_MESSAGE') else ''}\n"
        f"{env.get('CI_PIPELINE_URL', '')}"
    )
    webhook = f"https://discord.com/api/webhooks/{env['DISCORD_ID']}/{env['DISCORD_TOKEN']}"
    request = urllib.request.Request(
        webhook,
        data=json.dumps({"content": message}).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "devenv-ci"},
    )
    urllib.request.urlopen(request, timeout=20).close()
    print(message)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
