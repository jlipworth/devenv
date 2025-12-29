# Python Layer Runbook for Spacemacs

This runbook documents common issues and solutions for Python development in Spacemacs with LSP (pyright) backend.

## Current Configuration

```elisp
(python :variables
        python-backend 'lsp
        python-lsp-server 'pyright
        python-formatter 'ruff
        python-poetry-activate nil
        python-enable-tools '(pip poetry))

(conda :variables
       conda-anaconda-home (expand-file-name "miniconda3" (getenv "HOME")))
```

---

## Issue 1: IPython REPL Autocomplete Not Working

**Symptoms:**
- Typing `np.` after `import numpy as np` shows `[no matches]`
- TAB completion returns nothing for methods/attributes
- Filename completion works, but Python objects don't complete

**Root Cause:**
The inferior-python-mode buffer doesn't have company-mode backends properly configured. This is independent of the LSP backend (pyright) - the REPL uses a separate completion mechanism.

Reference: [GitHub Issue #11785](https://github.com/syl20bnr/spacemacs/issues/11785)

### Solution A: Ensure Conda/Virtualenv is Active

The REPL completion requires the Python environment to be properly activated.

```elisp
;; In user-config, ensure conda activates before REPL
(add-hook 'python-mode-hook
          (lambda ()
            (when (and (boundp 'conda-env-current-name)
                       (not conda-env-current-name))
              (conda-env-activate-for-buffer))))
```

**Manual check:** Before starting REPL, run `, V a` (`conda-env-activate`) or `SPC m V a`.

### Solution B: Manually Configure Company for REPL

Add to `user-config`:

```elisp
(add-hook 'inferior-python-mode-hook
          (lambda ()
            (company-mode 1)
            (setq-local company-backends '(company-capf company-files))))
```

### Solution C: Switch to emacs-jupyter (Recommended)

The `emacs-jupyter` package provides a more robust REPL with better completion.

**Step 1:** Install jupyter in your Python environment:
```bash
pip install jupyter
```

**Step 2:** Add the jupyter layer or package:

Option 1 - Use the community layer:
```elisp
;; Clone https://github.com/benneti/spacemacs-jupyter to ~/.emacs.d/private/jupyter
;; Then add to dotspacemacs-configuration-layers:
jupyter
```

Option 2 - Add as additional package:
```elisp
dotspacemacs-additional-packages '(jupyter)
```

**Step 3:** Configure completion hook in `user-config`:
```elisp
(with-eval-after-load 'jupyter
  (add-hook 'jupyter-repl-mode-hook
            (lambda ()
              (company-mode 1)
              (setq-local company-backends '(company-capf)))))
```

**Step 4:** Use `, s i` or `SPC m s i` to start jupyter REPL instead of inferior-python.

Reference: [spacemacs-jupyter layer](https://github.com/benneti/spacemacs-jupyter), [emacs-jupyter](https://github.com/emacs-jupyter/jupyter)

### Troubleshooting REPL Completion

1. **Check if company-mode is active:**
   ```
   M-x describe-mode RET
   ```
   Look for "Company" in minor modes.

2. **Check company backends:**
   ```
   M-x describe-variable RET company-backends RET
   ```
   Should include `company-capf`.

3. **Verify Python environment:**
   In the REPL, run:
   ```python
   import sys; print(sys.executable)
   ```
   Ensure it points to your conda/venv Python.

4. **IPython-specific issue - freezing on TAB:**
   If Emacs freezes when pressing TAB inside a function:
   - This is a known IPython bug
   - Workaround: Use `M-/` (dabbrev) or switch to jupyter

---

## Issue 2: Intrusive Horizontal Split Documentation Popup

**Symptoms:**
- A large window appears below your code when cursor enters a function call
- Window shows function signature and docstring
- Disrupts window layout, requires scrolling to get back to code

**Root Cause:**
This is `lsp-signature-help`, NOT `lsp-ui-doc`. It uses a buffer split rather than a floating frame.

Reference: [lsp-mode Issue #1535](https://github.com/emacs-lsp/lsp-mode/issues/1535)

### Solution A: Disable Signature Auto-Activation (Recommended)

Add to your LSP layer configuration:

```elisp
(lsp :variables
     lsp-enable-snippet t
     lsp-log-io nil
     lsp-auto-guess-root t
     ;; Disable the intrusive signature popup
     lsp-signature-auto-activate nil)
```

Or in `user-config`:
```elisp
(setq lsp-signature-auto-activate nil)
```

You can still manually request signature help with:
- `, h h` or `SPC m h h` - describe thing at point
- `M-x lsp-signature-activate` - manual trigger

### Solution B: Keep Signature but Hide Documentation

If you want the function signature but not the full docstring:

```elisp
(setq lsp-signature-render-documentation nil)
```

This shows only the parameter list, not the full documentation.

### Solution C: Use Eldoc Instead (Minimal)

For a less intrusive experience, use eldoc in the echo area:

```elisp
(setq lsp-signature-auto-activate nil)
(setq lsp-eldoc-enable-hover t)
(setq lsp-eldoc-render-all nil)  ;; signature only, not full docs
```

### Troubleshooting Signature Help

1. **Identify what's causing the popup:**
   When the popup appears, check the buffer name:
   - `*lsp-help*` = lsp-describe-thing-at-point
   - `*eldoc*` or echo area = eldoc
   - Child frame = lsp-ui-doc

2. **If popup persists after setting variables:**
   The variable must be set BEFORE lsp-mode starts. Try:
   ```elisp
   ;; In user-init (not user-config)
   (setq lsp-signature-auto-activate nil)
   ```

3. **Nuclear option - disable all hover features:**
   ```elisp
   (setq lsp-enable-hover nil)
   ```

---

## Issue 3: Poor Documentation Experience (Pydoc)

**Symptoms:**
- `pydoc` buffers are hard to navigate
- No VS Code-style inline documentation
- Want "intellisense"-like quick docs

### Solution A: Configure lsp-ui-doc for Floating Popups

```elisp
(lsp :variables
     ;; ... existing config ...
     ;; Enable floating doc frames
     lsp-ui-doc-enable t
     lsp-ui-doc-show-with-cursor nil   ;; don't auto-show
     lsp-ui-doc-show-with-mouse t      ;; show on mouse hover
     lsp-ui-doc-position 'at-point     ;; or 'top, 'bottom
     lsp-ui-doc-delay 0.5              ;; seconds before showing
     lsp-ui-doc-include-signature t    ;; include function signature
     lsp-ui-doc-max-height 20
     lsp-ui-doc-max-width 80)
```

### Solution B: On-Demand Doc Glance

Add keybinding for quick doc peek that auto-hides:

```elisp
;; In user-config
(spacemacs/set-leader-keys-for-major-mode 'python-mode
  "hg" 'lsp-ui-doc-glance)   ;; SPC m h g - glance at docs
```

Also available:
- `, h h` / `SPC m h h` - `lsp-describe-thing-at-point` (full docs in buffer)
- `K` in normal mode - quick documentation (if configured)

### Solution C: Focus into Doc Frame

When lsp-ui-doc popup is visible, you can focus into it:

```elisp
(spacemacs/set-leader-keys-for-major-mode 'python-mode
  "hf" 'lsp-ui-doc-focus-frame)   ;; SPC m h f - focus doc frame
```

Once focused, use `q` to close.

### Solution D: WebKit Rendering (Better Formatting)

If you compiled Emacs with `--with-xwidgets`:

```elisp
(setq lsp-ui-doc-use-webkit t)
```

This renders documentation with better formatting but requires xwidgets support.

### Troubleshooting lsp-ui-doc

1. **Child frame not appearing on macOS:**
   - Check if you use a tiling window manager (yabai, chunkwm)
   - These can interfere with child frames
   - Try: `(setq lsp-ui-doc-use-childframe nil)` for buffer-based fallback

2. **Emacs freezes when scrolling doc frame:**
   - Known issue on macOS with long docstrings
   - Fix: Enable webkit rendering OR disable childframe
   Reference: [lsp-ui Issue #619](https://github.com/emacs-lsp/lsp-ui/issues/619)

3. **Doc frame appears in wrong position:**
   - Try different position values: `'top`, `'bottom`, `'at-point`
   - Reference: [lsp-ui Issue #107](https://github.com/emacs-lsp/lsp-ui/issues/107)

4. **Check if lsp-ui is loaded:**
   ```
   M-x describe-variable RET lsp-ui-doc-mode RET
   ```

---

## Pyright-Specific Configuration

### Performance Tuning

If pyright is slow ([Issue #14210](https://github.com/syl20bnr/spacemacs/issues/14210)):

```elisp
;; Reduce type checking strictness
(setq lsp-pyright-type-checking-mode "off")  ;; or "basic"

;; Disable features you don't need
(setq lsp-pyright-auto-import-completions nil)
```

### Virtual Environment Detection

lsp-pyright searches for Python in this order:
1. `.venv/` or `venv/` in project root
2. Conda environment (if conda layer active)
3. System PATH

To force a specific Python:

```elisp
(setq lsp-pyright-venv-path "/path/to/your/venv")
;; OR
(setq lsp-pyright-python-executable-cmd "/path/to/python")
```

### Project Configuration

Create `pyrightconfig.json` in project root:

```json
{
  "venvPath": ".",
  "venv": ".venv",
  "pythonVersion": "3.11",
  "typeCheckingMode": "basic",
  "stubPath": ""
}
```

Setting `"stubPath": ""` prevents the "typings is not a valid directory" warning.

Reference: [lsp-pyright](https://github.com/emacs-lsp/lsp-pyright), [Pyright Configuration](https://github.com/microsoft/pyright/blob/main/docs/configuration.md)

### Troubleshooting Pyright

1. **Check if pyright is running:**
   ```
   M-x lsp-describe-session RET
   ```
   Look for "pyright" in the server list.

2. **View LSP logs:**
   ```elisp
   (setq lsp-log-io t)  ;; temporarily enable
   ```
   Then check `*lsp-log*` buffer.

3. **Wrong Python detected:**
   ```
   M-x lsp-pyright-locate-python RET
   ```
   Shows which Python pyright is using.

4. **Restart LSP after environment change:**
   ```
   M-x lsp-workspace-restart RET
   ```

---

## Recommended Complete Configuration

Add this to your `.spacemacs`:

```elisp
;; In dotspacemacs-configuration-layers:
(lsp :variables
     lsp-enable-snippet t
     lsp-log-io nil
     lsp-auto-guess-root t
     ;; Disable intrusive signature popup
     lsp-signature-auto-activate nil
     lsp-signature-render-documentation nil
     ;; Configure lsp-ui-doc for on-demand use
     lsp-ui-doc-enable t
     lsp-ui-doc-show-with-cursor nil
     lsp-ui-doc-show-with-mouse t
     lsp-ui-doc-position 'at-point
     lsp-ui-doc-delay 0.3
     lsp-ui-doc-include-signature t
     ;; Eldoc in echo area
     lsp-eldoc-enable-hover t
     lsp-eldoc-render-all nil)

(python :variables
        python-backend 'lsp
        python-lsp-server 'pyright
        python-formatter 'ruff
        python-poetry-activate nil
        python-enable-tools '(pip poetry))

;; In user-config:
(defun dotspacemacs/user-config ()
  ;; ... existing config ...

  ;; Fix REPL completion
  (add-hook 'inferior-python-mode-hook
            (lambda ()
              (company-mode 1)
              (setq-local company-backends '(company-capf company-files))))

  ;; Optional: jupyter REPL completion
  (with-eval-after-load 'jupyter
    (add-hook 'jupyter-repl-mode-hook
              (lambda ()
                (company-mode 1)
                (setq-local company-backends '(company-capf)))))

  ;; Custom keybindings for documentation
  (spacemacs/set-leader-keys-for-major-mode 'python-mode
    "hg" 'lsp-ui-doc-glance
    "hf" 'lsp-ui-doc-focus-frame)
)
```

---

## Quick Reference: Keybindings

| Key | Command | Description |
|-----|---------|-------------|
| `, h h` | `lsp-describe-thing-at-point` | Full documentation in buffer |
| `, h g` | `lsp-ui-doc-glance` | Quick peek (auto-hides) |
| `, h f` | `lsp-ui-doc-focus-frame` | Focus into doc popup |
| `, g g` | `lsp-find-definition` | Go to definition |
| `, g r` | `lsp-find-references` | Find references |
| `, s i` | `python-start-or-switch-repl` | Start REPL |
| `, V a` | `conda-env-activate` | Activate conda env |
| `K` | evil-lookup / doc | Quick docs (in normal mode) |

---

## Sources

- [Spacemacs Python Layer](https://develop.spacemacs.org/layers/+lang/python/README.html)
- [Spacemacs LSP Layer](https://develop.spacemacs.org/layers/+tools/lsp/README.html)
- [lsp-ui Documentation](https://emacs-lsp.github.io/lsp-ui/)
- [lsp-pyright](https://github.com/emacs-lsp/lsp-pyright)
- [emacs-jupyter](https://github.com/emacs-jupyter/jupyter)
- [spacemacs-jupyter layer](https://github.com/benneti/spacemacs-jupyter)
- [Modernizing Python in Emacs (2024)](https://slinkp.com/python-emacs-lsp-20231229.html)
