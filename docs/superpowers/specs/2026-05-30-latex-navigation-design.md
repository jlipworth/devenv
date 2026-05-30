# LaTeX Navigation — Design

Date: 2026-05-30
Status: Draft (awaiting user review)
Issue: #21 "Latex Navigation"
Scope: Make moving through LaTeX expressions and sections in Spacemacs less
cumbersome, wired the Spacemacs way (which-key, declared prefixes, docs).

## 1. Goal & Non-Goals

### Goal

Address the two navigation pains called out for issue #21:

- **(A) Moving within expressions** — operating on / hopping through the
  math and markup structure around the cursor (`{}`, `[]`, `$...$`, command
  args, `\begin`/`\end` environments).
- **(B) Jumping between sections** — moving heading-to-heading through a
  document and fuzzy-jumping to any section.

Everything new must be discoverable through standard Spacemacs mechanisms:
leader keys registered with `spacemacs/set-leader-keys-for-major-mode`
(automatic which-key entries), grouped under a named prefix via
`spacemacs/declare-prefix-for-mode`, plus a written cheatsheet.

### Non-Goals

- **Cross-references / labels / citations.** RefTeX already covers this under
  `SPC m r …` (the layer's reftex prefix). Out of scope.
- **Source ↔ PDF (SyncTeX) navigation.** Out of scope for this pass.
- **Custom which-key label overrides for the `]]` / `[[` motions.** Per user:
  keep standard idioms — if evil motions surface in which-key on their own,
  fine; do not add bespoke `which-key` replacement entries to force it. The
  leader-key bindings carry guaranteed discoverability.
- **New packages.** evil-tex, evil-matchit, and reftex are already enabled by
  the Spacemacs `latex` layer; this work adds thin glue and docs only.
- **Approach 2 (heavier structural nav).** outline-minor-mode folding/tree
  navigation and environment motions are explicitly deferred — see §6.

### Success Criteria

1. `SPC m j` shows a `jump` group in which-key for `latex-mode`, containing
   next/previous-section and fuzzy-jump entries.
2. `]]` / `[[` move to the next / previous section heading in normal,
   visual, and operator-pending state, and respect a numeric count.
3. A cheatsheet in `docs/SPACEMACS_PRODUCTIVITY.md` documents the new section
   nav plus the already-shipped evil-tex text objects and `%` matchit, so the
   discoverability half of (A) is resolved in writing.

## 2. Current State

Spacemacs `latex` layer (`~/.emacs.d/layers/+lang/latex/packages.el`) already
wires up, with no action from us:

- **evil-tex** — `LaTeX-mode-hook #'evil-tex-mode` (packages.el:207). Text
  objects work today: `cie`/`die` (change/delete in environment), `ci$`
  (inline math), command / delimiter / sub-superscript objects, and the
  `evil-tex` toggle map under `SPC m` (packages.el:208-212).
- **evil-matchit** — `LaTeX-mode-hook 'evil-matchit-mode` (packages.el:194).
  `%` jumps between matched `\begin`/`\end` and delimiter pairs.
- **reftex** — `reftex-toc` at `SPC m r t` (packages.el:232); the full
  `SPC m r …` reference workflow.

Gaps:

- **No section-to-section motion.** `]]` / `[[` are not bound in LaTeX-mode;
  there is no heading-hop command.
- **No fast "jump to a section."** The only structural overview is opening the
  `reftex-toc` buffer.
- **Expression navigation is undocumented**, so the existing evil-tex / `%`
  capability is effectively invisible.

Existing custom config lives in `jal-functions.el`, loaded from user-config
*after* layers init (see `jal-functions.el:130`), already binding latex-mode
leader keys (`jal-functions.el:136-138`). New code follows the same pattern —
no `.spacemacs` change required.

Top-level `SPC m` letters already used in latex-mode:
`\ - % ; k l m n N v h x a b z * . i s f p c e` (plus `au c iC ic ie` under the
LSP backend). **`j` is free** and is the conventional Spacemacs "jump" letter.

## 3. Implementation

All in `jal-functions.el`, in the `;;;; Keybindings` region alongside the
existing latex-mode block.

### 3.1 Section motions (build on AUCTeX outline machinery)

AUCTeX sets a buffer-local `outline-regexp` / `outline-level` for sectioning
commands in LaTeX buffers, so we reuse `outline-next-heading` /
`outline-previous-heading` rather than hardcoding a section regexp. Define them
as evil motions so they honor counts and operator/visual state:

```elisp
(evil-define-motion jal/latex-next-section (count)
  "Move to the next LaTeX section heading."
  :jump t
  (dotimes (_ (or count 1))
    (outline-next-heading)))

(evil-define-motion jal/latex-previous-section (count)
  "Move to the previous LaTeX section heading."
  :jump t
  (dotimes (_ (or count 1))
    (outline-previous-heading)))
```

`:jump t` records the prior position in the evil jump list so `C-o` returns.

### 3.2 Leader keys (guaranteed which-key + docs)

```elisp
(spacemacs/declare-prefix-for-mode 'latex-mode "mj" "jump")
(spacemacs/set-leader-keys-for-major-mode 'latex-mode
  "jn" 'jal/latex-next-section
  "jp" 'jal/latex-previous-section
  "jj" 'helm-imenu)
```

`helm-imenu` gives a flat, filterable list of the buffer's sections (AUCTeX
populates the imenu index). Chosen provisionally; the reftex-toc tree remains
available at `SPC m r t` if the flat list proves wrong (see Open Questions).

### 3.3 Vim motions (fast path)

```elisp
(evil-define-key '(normal visual operator) LaTeX-mode-map
  "]]" 'jal/latex-next-section
  "[[" 'jal/latex-previous-section)
```

No custom which-key replacements added (per §1 Non-Goals).

### 3.4 Documentation

Add a "LaTeX navigation" subsection to `docs/SPACEMACS_PRODUCTIVITY.md`
covering:

- Section nav: `]]` / `[[`, `SPC m j n/p`, `SPC m j j`, and existing
  `SPC m r t` (reftex-toc).
- Expression nav (already shipped): evil-tex text objects
  (`cie`/`die`/`ci$`/command/delimiter/script), and `%` (evil-matchit) to
  hop `\begin`/`\end` and delimiter pairs.

## 4. Files Touched

- `jal-functions.el` — two `evil-define-motion` defuns, one
  `declare-prefix-for-mode`, one leader-key block, one `evil-define-key`
  block.
- `docs/SPACEMACS_PRODUCTIVITY.md` — new navigation cheatsheet subsection.

## 5. Risks & Verification

- **`outline-regexp` availability.** The motions assume AUCTeX has set
  `outline-regexp` in the buffer. Verify in a real `.tex` buffer that
  `outline-next-heading` lands on `\section`/`\subsection`/`\frame` headings;
  if AUCTeX's default outline level excludes a sectioning command in use, note
  it in docs.
- **`LaTeX-mode-map` load timing.** `evil-define-key` on `LaTeX-mode-map` must
  run after AUCTeX is loaded. jal-functions.el loads after layers init, but
  confirm the map is defined at eval time (wrap in `with-eval-after-load 'latex`
  if it is not).
- **`helm-imenu` availability.** Config is helm-based; confirm `helm-imenu` is
  bound and indexes sections in a real buffer.
- **Headless validation.** Use the headless-config-validation /
  headless-editor-debugging skills to confirm the file evaluates clean and the
  bindings register, before manual spot-check.

## 6. Approach-2 Extension Points (deferred)

Because the section commands build on `outline-regexp`, these slot in later
without rework:

- Enable `outline-minor-mode` in LaTeX for folding + tree navigation.
- Environment motions (`]e` / `[e`, and `SPC m j N` / `SPC m j P`) using
  evil-tex's environment boundaries.
- Reconsider `SPC m j j` target (helm-imenu vs. reftex-toc) once used in anger.
