;;; jal-functions.el --- Custom Emacs functions -*- lexical-binding: t; -*-

;; Author: JAL
;; Description: Custom functions loaded by Spacemacs user-config

;;; Commentary:
;; Load via (add-to-list 'load-path "~/GNU_files") in user-init
;; and (require 'jal-functions) in user-config

;;; Code:

;;;; Customization

(defgroup jal nil
  "Personal customizations and helper functions."
  :group 'convenience)

;;;; Date insertion

(defun jal/insert-current-date ()
  "Insert the current date in 'Mon DD, YYYY' format."
  (interactive)
  (when (fboundp 'evil-append)
    (evil-append 1))
  (insert (format-time-string "%b %d, %Y")))

;;;; Mermaid support

(defun jal/markdown-compile-mermaid-at-point ()
  "Compile mermaid code block at point in markdown and display the result."
  (interactive)
  (save-excursion
    (when (re-search-backward "```mermaid" nil t)
      (forward-line 1)
      (let ((start (point)))
        (when (re-search-forward "```" nil t)
          (forward-line 0)
          (let ((code (buffer-substring-no-properties start (point)))
                (tmp-file (make-temp-file "mermaid-" nil ".mmd"))
                (out-file (make-temp-file "mermaid-" nil ".png")))
            (with-temp-file tmp-file (insert code))
            (if (zerop (call-process "mmdc" nil nil nil "-i" tmp-file "-o" out-file))
                (find-file out-file)
              (message "Mermaid compilation failed"))))))))

;; mermaid-mode keybindings (for .mmd/.mermaid files)
(with-eval-after-load 'mermaid-mode
  (when (boundp 'spacemacs/set-leader-keys-for-major-mode)
    (spacemacs/set-leader-keys-for-major-mode 'mermaid-mode
      "c" 'mermaid-compile
      "b" 'mermaid-compile-buffer
      "r" 'mermaid-compile-region
      "o" 'mermaid-open-browser
      "d" 'mermaid-open-doc)))

;;;; WSL2 SSH agent fix

(defun jal/setup-ssh-agent ()
  "Ensure SSH_AUTH_SOCK is set, particularly for WSL2."
  (unless (getenv "SSH_AUTH_SOCK")
    (message "No SSH_AUTH_SOCK set. Setting SSH_AUTH_SOCK")
    (when (fboundp 'exec-path-from-shell-initialize)
      (exec-path-from-shell-initialize)
      (exec-path-from-shell-copy-env "SSH_AUTH_SOCK")))
  (when (getenv "SSH_AUTH_SOCK")
    (message "Current SSH_AUTH_SOCK: %s" (getenv "SSH_AUTH_SOCK"))))

;;;; Terminal clipboard support

(defun jal/setup-terminal-clipboard ()
  "Enable clipboard integration for terminal Emacs via clipetty.
Only activates in non-graphical frames (e.g., Emacs -nw in tmux)."
  (unless (display-graphic-p)
    (when (require 'clipetty nil t)
      (global-clipetty-mode 1)
      (message "Clipetty enabled for terminal clipboard integration"))))

;;;; Context-aware quit

(defun jal/keyboard-quit-dwim ()
  "Do-What-I-Mean quit, suitable for binding to <escape> globally.

Unlike a bare `keyboard-quit', this dismisses whatever is actually
active:

- with an active region, cancel it;
- with a completion list open, close its window;
- inside the minibuffer (at any recursion depth), abort it -- even when
  point is in another window;
- otherwise fall back to `keyboard-quit'.

Works in GUI and terminal Emacs.  Evil binds <escape> in its own state
maps at higher priority, so this only takes effect where Evil does not
already handle it (minibuffer, completion, Emacs-state / special buffers)."
  (interactive)
  (cond
   ((region-active-p)
    (keyboard-quit))
   ((derived-mode-p 'completion-list-mode)
    (delete-completion-window))
   ((> (minibuffer-depth) 0)
    (abort-recursive-edit))
   (t
    (keyboard-quit))))

;;;; Startup UI tweaks

(defcustom jal-startup-frame-zoom-steps 3
  "Number of whole-frame zoom-in steps to apply on startup.

This uses Spacemacs' `SPC z f` (zoom-frm) feature, not buffer-local
`text-scale-mode`."
  :type 'integer
  :group 'jal)

(defconst jal--startup-frame-zoom-frame-parameter 'jal-startup-frame-zoom-applied
  "Frame parameter used to mark that startup zoom has been applied.")

(defun jal//apply-startup-frame-zoom-to-frame (frame steps)
  "Apply STEPS of whole-frame zoom to FRAME (idempotent per FRAME)."
  (with-selected-frame frame
    (when (and (display-graphic-p frame)
               (integerp steps)
               (> steps 0)
               (not (frame-parameter frame jal--startup-frame-zoom-frame-parameter))
               (fboundp 'spacemacs/zoom-frm-in))
      (dotimes (_ steps)
        (spacemacs/zoom-frm-in))
      (set-frame-parameter frame jal--startup-frame-zoom-frame-parameter t))))

(defun jal//startup-frame-zoom-after-make-frame (frame)
  "Apply startup frame zoom to FRAME (for daemon / emacsclient workflows)."
  (jal//apply-startup-frame-zoom-to-frame frame jal-startup-frame-zoom-steps))

(defun jal/apply-startup-frame-zoom (&optional steps)
  "Zoom the whole frame in by STEPS (defaults to `jal-startup-frame-zoom-steps').

This is applied once per frame and remembered via a frame parameter, so reloading
your config won't keep zooming the current frame."
  (when (integerp steps)
    (setq jal-startup-frame-zoom-steps steps))
  ;; Apply to any already-existing frames.
  (dolist (frame (frame-list))
    (jal//apply-startup-frame-zoom-to-frame frame jal-startup-frame-zoom-steps))
  ;; Also apply to frames created later (daemon / emacsclient).
  (add-hook 'after-make-frame-functions #'jal//startup-frame-zoom-after-make-frame))

;;;; LaTeX navigation

;; Section motions match only sectioning commands. The regexp is derived from
;; AUCTeX's buffer-local `LaTeX-section-list' (part/chapter/section/subsection
;; ... plus any the document class adds), so it tracks what AUCTeX considers a
;; section -- unlike `outline-regexp', which also matches \documentclass,
;; environment \begin lines, etc. Defined as evil motions so they honor a
;; numeric count, work in operator/visual state, and push the prior point onto
;; the jump list.

(defun jal//latex-section-regexp ()
  "Return a regexp matching any sectioning command known to AUCTeX.
Anchored at line start so it lands on the heading, not on an inline
cross-reference to it."
  (concat "^[ \t]*" (regexp-quote TeX-esc)
          "\\(?:"
          (mapconcat (lambda (entry) (regexp-quote (car entry)))
                     LaTeX-section-list "\\|")
          "\\)\\*?"))

(evil-define-motion jal/latex-next-section (count)
  "Move to the next LaTeX section heading.
With COUNT, move that many headings forward."
  :jump t
  (let ((re (jal//latex-section-regexp))
        (case-fold-search nil))
    (dotimes (_ (or count 1))
      (end-of-line)                       ; step off the current heading line
      (if (re-search-forward re nil t)
          (goto-char (match-beginning 0))
        (goto-char (point-max))))))

(evil-define-motion jal/latex-previous-section (count)
  "Move to the previous LaTeX section heading.
With COUNT, move that many headings backward."
  :jump t
  (let ((re (jal//latex-section-regexp))
        (case-fold-search nil))
    (dotimes (_ (or count 1))
      (beginning-of-line)                 ; step off the current heading line
      (if (re-search-backward re nil t)
          (goto-char (match-beginning 0))
        (goto-char (point-min))))))

;;;; Configuration

;; ob-mermaid babel integration (must defer until org loads)
(with-eval-after-load 'org
  (require 'ob-mermaid)
  (add-to-list 'org-babel-load-languages '(mermaid . t))
  (org-babel-do-load-languages 'org-babel-load-languages org-babel-load-languages)
  (setq ob-mermaid-cli-path (executable-find "mmdc")))

;;;; Keybindings
;; Direct calls - this file is loaded from user-config after layers init

;; org-mode: SPC m o c - insert date
(spacemacs/set-leader-keys-for-major-mode 'org-mode
  "oc" 'jal/insert-current-date)

;; latex-mode: SPC m o c - insert date
(spacemacs/set-leader-keys-for-major-mode 'latex-mode
  "oc" 'jal/insert-current-date)

;; latex-mode: section navigation (SPC m j ...)
(spacemacs/declare-prefix-for-mode 'latex-mode "mj" "jump")
(spacemacs/set-leader-keys-for-major-mode 'latex-mode
  "jn" 'jal/latex-next-section
  "jp" 'jal/latex-previous-section
  "jj" 'helm-imenu)

;; latex-mode: vim-style section motions. LaTeX-mode-map is only defined once
;; AUCTeX's `latex' feature loads (it is deferred), so bind after load.
(with-eval-after-load 'latex
  (evil-define-key '(normal visual operator) LaTeX-mode-map
    "]]" 'jal/latex-next-section
    "[[" 'jal/latex-previous-section))

;; markdown/gfm-mode: SPC m M - compile mermaid at point
(spacemacs/set-leader-keys-for-major-mode 'markdown-mode
  "M" 'jal/markdown-compile-mermaid-at-point)
(spacemacs/set-leader-keys-for-major-mode 'gfm-mode
  "M" 'jal/markdown-compile-mermaid-at-point)

(provide 'jal-functions)
;;; jal-functions.el ends here
