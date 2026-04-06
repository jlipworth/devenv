---
name: headless-config-validation
description: "Use when you have modified .spacemacs, jal-functions.el, any file under nvim/, or Emacs Lisp in this repo and need to verify the change does not break editor startup or package loading."
---

# Headless Config Validation

After modifying Emacs or Neovim configuration in this repo, run the appropriate headless check before claiming the change is safe.

## What You Changed -> What to Run

| Changed file(s) | Validation command |
|---|---|
| `.spacemacs` | Spacemacs syntax + layer parse (both below) |
| `jal-functions.el` | Elisp load check |
| `nvim/init.lua` or `nvim/lua/config/*.lua` | Neovim config parse |
| `nvim/lua/plugins/*.lua` | Lazy plugin spec check |
| Any `.el` file | Elisp load check |

## Emacs / Spacemacs Commands

**Syntax check** (does the file parse as valid Elisp?):
```bash
emacs --batch -l ~/.spacemacs --eval '(message "syntax ok")'
```

**Layer list parse** (does `dotspacemacs/layers` evaluate without error?):
```bash
emacs --batch --eval '(progn (setq debug-on-error t) (load-file "~/.spacemacs") (dotspacemacs/layers) (message "layers ok"))'
```

**Custom Elisp load check** (standalone files only):
```bash
emacs --batch -l <file>.el --eval '(message "loaded ok")'
```
Note: Files that call Spacemacs functions (e.g., `jal-functions.el` uses `spacemacs/set-leader-keys-for-major-mode`) will fail in bare batch mode. Test those with the full init instead: `emacs --batch -l ~/.emacs.d/init.el`.

**Exit code:** 0 = success. Non-zero = error. Stderr contains the Elisp backtrace on failure.

## Neovim Commands

**Config parse** (does init.lua load without errors?):
```bash
nvim --headless -c 'qall'
```
Silent exit = success. Errors print to stderr.

**Lazy plugin load test** (confirms all specs parse and plugins load):
```bash
nvim --headless -c 'lua print(require("lazy").stats().count .. " plugins")' -c 'qall'
```

**Lazy sync** (install missing plugins, useful after spec changes):
```bash
nvim --headless "+Lazy! sync" +qa
```

**Checkhealth for a plugin:**
```bash
nvim --headless -c 'checkhealth <plugin-name>' -c 'qall'
```

## Interpreting Output

- **Clean exit (rc=0), no stderr** — config is valid.
- **Emacs prints `Symbol's value as variable is void`** — misspelled variable or missing `require`.
- **Emacs prints `Cannot open load file`** — missing package or wrong load-path.
- **Neovim prints `E5113`** — Lua error in config. Read the traceback for file and line.
- **Neovim prints `Failed to run \`config\``** — Lazy.nvim plugin config block has an error.

## CI Context

In CI (`CI=true`), Emacs is built from source at `~/.local/bin/emacs`. Neovim may not be on PATH unless the neovim build step ran. Set `PATH="$HOME/.local/bin:$HOME/.local/neovim/bin:$PATH"` if needed.
