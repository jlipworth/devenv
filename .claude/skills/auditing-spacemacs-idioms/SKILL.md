---
name: auditing-spacemacs-idioms
description: Use when checking whether ~/GNU_files/.spacemacs has drifted from the current Spacemacs dotfile template, or whether the prereq packages (prereq_packages.sh, requirements.txt, brewfiles/) still match what the enabled layers idiomatically expect — e.g. periodic "am I still idiomatic" sweeps, after big upstream shifts like custom tools → lsp.
---

# Auditing .spacemacs and Prereqs Against Current Spacemacs Idioms

## Overview

Two-part periodic audit (a few times a year): (1) has upstream moved the
dotfile template/defaults underneath `~/GNU_files/.spacemacs`; (2) do the
prereq installers still install what the enabled layers *currently* expect.
The Spacemacs checkout is `~/.emacs.d` (fork; local `develop` mirrors
upstream — sync it first via that repo's `syncing-with-upstream` skill).

This is heavy, read-only research — dispatch it to a subagent and keep only
the report. Every claim needs `file:line` or README-section evidence.

## Part 1 — dotfile vs template drift

| Source of truth | Where |
|---|---|
| Template | `~/.emacs.d/core/templates/dotspacemacs-template.el` (NOT `.spacemacs.template`) |
| Authoritative variable list | `spacemacs|defc` forms in `~/.emacs.d/core/core-dotspacemacs.el` |
| Default-change history | `git -C ~/.emacs.d log -S <var-name> -- core/core-dotspacemacs.el` |

Check three drift classes:
- **(a)** template variables missing from the dotfile (new knobs);
- **(b)** dotfile variables removed/renamed upstream (also check obsolete
  keywords silently stripped by core, e.g. `core/core-fonts-support.el`
  dropping `:powerline-scale`), and layer `:variables` that the layer no
  longer reads — verify each against the layer's source;
- **(c)** values that are just the *old* default plus the old template
  comment, where upstream changed the default (compare comment text against
  the current template; confirm with git history).

Deliberate customizations are NOT drift. Ignore comment/scaffolding diffs.
Pitfall: grep layer names with `rg -F` — `c-c++` contains regex chars and
plain patterns false-negative.

## Part 2 — prereq idiomaticity

Enabled layers = `dotspacemacs-configuration-layers` in the dotfile.
Installed prereqs = `prereq_packages.sh`, `requirements.txt`,
`brewfiles/Brewfile.*`, plus the aggregate targets (`install_all` in
prereq_packages.sh, `prereq-layers-all` in the makefile).

For each language/tool layer, the layer's `README.org` under
`~/.emacs.d/layers/+lang/` or `+tools/` is the source of truth for the
external tools it currently expects (LSP servers, formatters, linters,
debug adapters) — but READMEs can lag the code; when they conflict, trust
`packages.el`/`config.el` (e.g. html's README still names deprecated npm
servers; `vscode-langservers-extracted` is the modern replacement).

Flag:
- installed tools the layer no longer uses (legacy pre-lsp era);
- tools the configured backend needs that no prereq installs;
- idiom shifts where the config sits on the legacy side (custom tool → lsp
  server, renamed binaries like `lldb-vscode` → `lldb-dap`);
- enabled layers missing from the aggregate install targets.

Backends often need no explicit setting: several layers (sql, latex, and
terraform — the latter under `+tools/`) auto-default to `'lsp` when the lsp
layer is present — an unset backend is not drift; check the layer's
`config.el`.

## Report format

Two sections matching the parts, each a table (item / evidence / status /
recommendation) plus brief prose, ending with a prioritized shortlist
(max ~8) of changes actually worth making. Only genuine drift — no padding.
