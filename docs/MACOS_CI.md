# Native macOS CI

GNU_files keeps its existing Linux/container pipelines and adds a separate,
native Apple Silicon lane for the parts that Linux cannot prove. The native
lane uses a Woodpecker **local backend**, so repository commands run directly
on the Mac runner and must not be trusted with arbitrary fork code.

## Current rollout state

`.woodpecker/macos.yml` is intentionally restricted to manual events and asks
for these runner labels:

```yaml
platform: darwin/arm64
backend: local
purpose: mac-ci
```

The pipeline is also restricted to the repository's `master` branch. It should
remain manual-only until the Mac runner is provisioned and
the repository is explicitly approved as a trusted workload. The GitHub repo is
public, so fork pull requests must never run on this local backend. Enabling
owner-controlled push runs is a separate post-enrollment change.

## Safety model

`ci/macos-full-setup.sh` provides isolation that `NO_ADMIN=true` alone does not:

- creates a disposable `HOME`;
- installs the test Emacs under a disposable `EMACS_PREFIX`;
- redirects npm global installs into that disposable home;
- sets `NO_ADMIN=true`, `CI=true`, and `CI_INSTALL=true`;
- replaces `brew` with a read-only facade;
- replaces `sudo` with a deny guard;
- deletes the workspace after the job, including on failure.

Homebrew dependencies are runner prerequisites. The CI job may query them, but
it cannot install, update, remove, link, or start Homebrew services. Calls such
as `brew install` and `brew bundle` in the general setup scripts are converted
to presence checks. A missing package fails the job and must be corrected by
the runner-provisioning workflow, not by weakening the CI guard.

This protects the normal `ci` account's home and the shared Homebrew prefix. It
does not make the local backend a security sandbox; that is why repository
trust and event gating remain mandatory.

`ci/validate-macos-pipeline.py` enforces the three exact runner labels, a
manual-only event, and the default branch. It is run by portable lint CI, so a
change cannot silently weaken the native workflow during review. This is not
an agent-side event filter: Woodpecker must continue to require approval for
fork pipelines, and fork pipelines must never be approved while the native
agent is eligible.

## Runner preflight

After provisioning the runner's shared toolchain, run:

```bash
make macos-ci-preflight
```

The preflight requires:

- macOS and working Xcode Command Line Tools;
- Homebrew, Git, curl, and Python 3;
- every dependency declared by `brewfiles/Brewfile.*` already installed.

It is read-only. A failure names the Brewfile that runner provisioning must
satisfy.

## Full validation

The pipeline runs:

```bash
make macos-ci-setup
```

That target performs the existing `make full-setup` inside the disposable
environment, builds and installs Emacs under the temporary prefix, clones the
`jlipworth/spacemacs` `develop` branch into the temporary home, and explicitly
loads Spacemacs in batch mode. The final smoke therefore exercises both the
Emacs binary and the tracked `.spacemacs` configuration without touching the
runner user's personal editor environment.

For one-off diagnosis, retain the workspace:

```bash
MACOS_CI_KEEP_WORKSPACE=true make macos-ci-setup
```

The script prints the retained path. This should not be enabled in routine CI
because Emacs builds and package downloads consume substantial disk space.

## Local guard tests

The guard behavior can be tested without performing the full setup:

```bash
./tests/ci/macos_ci_spec.sh
```

The test verifies that read-only Homebrew queries work, missing dependencies
fail, mutating commands are blocked, and the Woodpecker pipeline remains
manual-only.

## Ownership boundaries

| Concern | Owner |
| --- | --- |
| Xcode, Homebrew, Brewfile prerequisites | Mac runner provisioning |
| Woodpecker agent, native `plugin-git`, and labels | Homelab/macOS automation |
| Disposable setup and Spacemacs smoke | This repository |
| Runner token and credentials | Secret management, never Git |
| Enabling non-manual events | Explicit post-enrollment review |
