---
name: headless-editor-debugging
description: "Use when a Spacemacs layer, Emacs package, or Neovim plugin is misbehaving — errors on load, missing features, broken keybindings, package conflicts, or unexpected behavior after config changes."
---

# Headless Editor Debugging

When an Emacs/Spacemacs or Neovim issue is reported, **reproduce it headlessly first**. Never guess at fixes without a reproduction command that shows the error.

## Step 1: Reproduce Headlessly

Try the simplest command first. If it fails, you have your reproduction.

**Emacs** (full Spacemacs init with stacktrace on error):
```bash
emacs --batch -l ~/.emacs.d/init.el
```

**Neovim:**
```bash
nvim --headless -c 'qall'
```

If these succeed but the problem is in a specific feature, narrow with Step 2.

## Step 2: Isolate

### Emacs Isolation Progression

1. **Single file without Spacemacs** — does the file load in vanilla Emacs?
   ```bash
   emacs -Q --batch -l <suspect-file.el>
   ```

2. **Single package** — does the package load independently?
   ```bash
   emacs --batch --eval '(progn (package-initialize) (require (quote <package-name>)))'
   ```

3. **Eval a specific form** — test the exact expression that fails:
   ```bash
   emacs --batch --eval '(progn (setq debug-on-error t) (load-file "~/.spacemacs") <form>)'
   ```

### Neovim Isolation Progression

1. **Clean config** — does it happen without your config?
   ```bash
   nvim --clean --headless -c '<command>' -c 'qall'
   ```

2. **Single plugin health:**
   ```bash
   nvim --headless -c 'checkhealth <plugin-name>' -c 'qall'
   ```

3. **Lazy plugin status** — which plugins failed to load?
   ```bash
   nvim --headless -c 'lua for _, p in ipairs(require("lazy").plugins()) do if not p._.loaded then print("NOT loaded: " .. p.name) end end' -c 'qall'
   ```

4. **Direct Lua eval:**
   ```bash
   nvim --headless -c 'lua <expression>' -c 'qall'
   ```

## Step 3: Diagnose

### Common Spacemacs Issues

| Symptom | Likely cause | Check |
|---|---|---|
| Package not found at startup | Layer not in `dotspacemacs-configuration-layers` | Grep `.spacemacs` for the layer name |
| `Symbol's function definition is void` | Deferred loading — function called before package loaded | Check `with-eval-after-load` / `use-package` `:defer` |
| Layer loads but keybindings missing | `dotspacemacs/user-config` overrides or wrong hook | Test binding in `emacs --batch --eval` |
| `Wrong number of arguments` | API changed after package update | Check package version with `emacs --batch --eval '(progn (package-initialize) (message "%s" (package-desc-version (cadr (assq (quote <pkg>) package-alist))))'` |

### Common Neovim / LazyVim Issues

| Symptom | Likely cause | Check |
|---|---|---|
| Plugin not loading | Wrong `event`, `cmd`, or `ft` trigger in spec | Check `nvim/lua/plugins/*.lua` for the trigger config |
| `module not found` | Plugin not installed or name mismatch | Run `nvim --headless "+Lazy! sync" +qa` then retry |
| Config error after update | Breaking change in plugin API | Check plugin repo changelog, pin to working commit |
| Conflicting keymaps | Two plugins mapping same key | Grep `nvim/lua/` for the key sequence |

## Step 4: Fix and Verify

After applying the fix, run the validation commands from the `headless-config-validation` skill to confirm the config is clean. Always verify both the specific issue AND overall config health.
