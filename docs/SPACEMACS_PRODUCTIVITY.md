# Spacemacs Productivity Tips

A collection of Spacemacs-native productivity enhancements to review and implement.

---

## Underused Keybindings Worth Learning

| Keybinding | What It Does | Notes |
|------------|--------------|-------|
| `SPC j i` | Jump to function/heading via imenu | Jump by name in current buffer |
| `SPC j I` | Imenu across all open buffers | Find function in any open file |
| `SPC s e` | iedit - edit all occurrences at once | Multi-cursor editing |
| `SPC s p` | Search in project (ripgrep/ag) | Grep across entire project |
| `SPC p l` | Switch between projects | Projectile project list |
| `SPC p f` | Find file in project | Fuzzy find, ignores node_modules etc. |
| `SPC r y` | Kill ring (paste history) | Browse previous yanks |
| `SPC SPC` | M-x with fuzzy matching | Run any command |
| `SPC h SPC` | Search layers/packages | Discover available layers |
| `SPC n f` | Narrow to function | Focus on current function only |
| `SPC n r` | Narrow to region | Focus on selected region |
| `SPC n w` | Widen | Return to full buffer |
| `SPC l l` | Switch layout | Workspace management |
| `SPC l s` | Save layout | Persist window arrangement |

---

## Recommended `dotspacemacs/user-config` Additions

Add these to your `.spacemacs` in the `dotspacemacs/user-config` function:

### Paste Transient State

Cycle through kill ring with `C-j`/`C-k` after pasting:

```elisp
;; Enable paste transient state - cycle through kill ring with C-j/C-k
(setq dotspacemacs-enable-paste-transient-state t)
```

### Better Search Defaults

Use ripgrep by default (faster than ag/grep):

```elisp
;; Prefer ripgrep for searches
(setq dotspacemacs-search-tools '("rg" "ag" "pt" "ack" "grep"))
```

### Layout Persistence

Resume previous window layout on restart:

```elisp
;; Resume layouts on restart
(setq dotspacemacs-auto-resume-layouts t)
```

### Frame Title

Show current file and project in window title:

```elisp
;; Show file and project in frame title
(setq frame-title-format '("%b - " (:eval (or (projectile-project-name) "no project"))))
```

### Smooth Scrolling

Less jarring scroll behavior:

```elisp
;; Smooth scrolling - keep cursor away from edges
(setq scroll-margin 5
      scroll-conservatively 101)
```

### Smart Parentheses

Auto-close brackets in all programming modes:

```elisp
;; Enable smartparens in all prog modes
(add-hook 'prog-mode-hook #'smartparens-mode)
```

### Faster Which-Key

Show keybinding hints faster:

```elisp
;; Show which-key popup faster (default 0.4)
(setq which-key-idle-delay 0.3)
```

### Magit Fullscreen

Git status takes full frame:

```elisp
;; Magit status opens fullscreen
(setq git-magit-status-fullscreen t)
```

---

## Layer Configuration Variables

Add these to `dotspacemacs-configuration-layers` in `.spacemacs`:

### Git Layer

```elisp
(git :variables
     git-magit-status-fullscreen t
     git-enable-github-support t)
```

### Auto-Completion Layer

```elisp
(auto-completion :variables
                 auto-completion-enable-snippets-in-popup t
                 auto-completion-enable-help-tooltip t
                 auto-completion-enable-sort-by-usage t)
```

### Syntax Checking Layer

```elisp
(syntax-checking :variables
                 syntax-checking-enable-tooltips t)
```

---

## Powerful Features Explained

### iedit (`SPC s e`)

Edit all occurrences of a word simultaneously:

1. Place cursor on a word
2. Press `SPC s e` - all occurrences highlight
3. Type to edit - all change at once
4. Press `ESC` when done

Use cases:
- Rename a variable across a function
- Change repeated text patterns
- Quick find-and-replace without regex

### Layouts (`SPC l`)

Workspace management - separate window arrangements per task:

| Key | Action |
|-----|--------|
| `SPC l s` | Save current layout |
| `SPC l l` | Switch to a layout |
| `SPC l 1-9` | Jump to layout by number |
| `SPC l d` | Delete current layout |
| `SPC l ?` | Show layout transient state |

Enable persistence:
```elisp
(setq dotspacemacs-auto-resume-layouts t)
```

### Narrowing (`SPC n`)

Focus on a portion of a buffer, hiding the rest:

| Key | Action |
|-----|--------|
| `SPC n f` | Narrow to current function |
| `SPC n r` | Narrow to selected region |
| `SPC n w` | Widen (return to full buffer) |

Use cases:
- Focus on one function while editing
- Reduce visual clutter
- Run commands only on narrowed region

### Imenu (`SPC j i`)

Jump to definitions by name:

- In code: jump to function/class definitions
- In org-mode: jump to headings
- `SPC j I` searches across all open buffers

### Registers (`SPC r`)

Store and recall text, positions, window configs:

| Key | Action |
|-----|--------|
| `SPC r s` | Save region to register |
| `SPC r i` | Insert register contents |
| `SPC r p` | Save point to register |
| `SPC r j` | Jump to saved point |
| `SPC r w` | Save window config to register |

---

## Performance Tips

### Leave Emacs Running

Emacs is designed to stay open. Use:
- `SPC q r` - Restart Spacemacs
- `SPC q R` - Restart and resume layouts
- `emacsclient` from terminal for instant file opening

### Disable Unused Layers

Comment out layers you don't use in `dotspacemacs-configuration-layers` to save memory and startup time.

### Lazy Load

Many layers support lazy loading. Heavy layers load only when needed.

---

## Quick Reference Card

### Navigation
```
SPC p f    Find file in project
SPC p p    Switch project
SPC b b    Switch buffer
SPC j i    Jump to imenu (function)
SPC /      Search in project
```

### Editing
```
SPC s e    iedit (multi-cursor)
SPC v      Expand region
SPC ;      Comment line/region
SPC x d w  Delete trailing whitespace
```

### Windows
```
M-1..9     Jump to window by number
SPC w /    Split vertical
SPC w -    Split horizontal
SPC w d    Delete window
SPC w m    Maximize window (toggle)
```

### Git (Magit)
```
SPC g s    Git status
SPC g b    Git blame
SPC g d    Git diff
SPC g c    Git commit
SPC g P    Git push
```

### Files
```
SPC f f    Find file
SPC f r    Recent files
SPC f s    Save file
SPC f e d  Edit .spacemacs
SPC f e R  Reload .spacemacs
```

---

## Sources

- [Spacemacs Documentation](https://develop.spacemacs.org/doc/DOCUMENTATION.html)
- [Spacemacs Tips](https://beppu.github.io/post/spacemacs-tips/)
- [Configuring Spacemacs Tutorial](https://thume.ca/howto/2015/03/07/configuring-spacemacs-a-tutorial/)
- [Spacemacs for Productivity](https://the-pi-guy.com/blog/spacemacs_for_productivity_tips_and_tricks_for_getting_the_most_out_of_emacs/)
- [Practicalli Spacemacs](https://practical.li/spacemacs/)

---

*Generated: December 2024*
