# CI

Woodpecker runs the workflows in `.woodpecker/`. Pull requests and pushes to
`master` trigger them; other branch pushes do not, since their pull request
covers them.

| Workflow | Runs when | What it checks |
| --- | --- | --- |
| `lint` | Every change | shellcheck, Codex config, macOS pipeline policy, script specs in `tests/` |
| `build` | Emacs/Neovim build inputs change | Emacs source build + Spacemacs load (`ci/spacemacs-smoke.sh`), Neovim source build |
| `layers` | Anything an installer can read changes | `make <layer>` for each layer in the CI image |
| `noadmin` | Same as `layers` | `NO_ADMIN=true` installs without sudo |
| `macos` | Setup files change on `master` (never PRs) | Full isolated setup on a Mac runner ([MACOS_CI.md](MACOS_CI.md)) |
| `notify` | After `lint` (and whichever others ran) | Discord status, read from the workflows' GitHub commit statuses (`ci/notify-discord.py`) |
| `renovate` | `renovate` cron | Dependency update PRs |

Path filters are in each workflow's `when:` block. `layers` and `noadmin` use
an exclude list (docs, Windows files, other workflows), so a new installer
input is covered by default; `build` and `macos` use include lists. Manual runs
ignore path filters.

## Crons

Configured in the Woodpecker repository settings, not in Git:

| Name | Schedule (UTC) | Runs |
| --- | --- | --- |
| `renovate` | `0 14 * * 1` | `renovate` |
| `weekly` | `0 6 * * 6` | Every other workflow, ignoring path filters, to catch upstream drift |

```bash
woodpecker-cli repo cron ls jlipworth/devenv
woodpecker-cli repo cron add jlipworth/devenv --name weekly --branch master --schedule "0 6 * * 6"
```
