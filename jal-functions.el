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

;;;; Startup UI tweaks

(defcustom jal-startup-frame-zoom-steps 2
  "Number of whole-frame zoom-in steps to apply on startup.

This uses Spacemacs' `SPC z f` (zoom-frm) feature, not buffer-local
`text-scale-mode`."
  :type 'integer
  :group 'jal)

(defvar jal--startup-frame-zoom-applied nil
  "Non-nil means startup frame zoom has already been applied this session.")

(defun jal/apply-startup-frame-zoom (&optional steps)
  "Zoom the whole frame in by STEPS, but only once per Emacs session."
  (let ((steps (or steps jal-startup-frame-zoom-steps)))
    (with-eval-after-load 'zoom-frm
      (unless jal--startup-frame-zoom-applied
        (setq jal--startup-frame-zoom-applied t)
        (when (fboundp 'spacemacs/zoom-frm-in)
          (dotimes (_ steps)
            (spacemacs/zoom-frm-in)))))))

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

;; markdown/gfm-mode: SPC m M - compile mermaid at point
(spacemacs/set-leader-keys-for-major-mode 'markdown-mode
  "M" 'jal/markdown-compile-mermaid-at-point)
(spacemacs/set-leader-keys-for-major-mode 'gfm-mode
  "M" 'jal/markdown-compile-mermaid-at-point)

(provide 'jal-functions)
;;; jal-functions.el ends here
