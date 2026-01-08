;;; jal-functions.el --- Custom Emacs functions -*- lexical-binding: t; -*-

;; Author: JAL
;; Description: Custom functions loaded by Spacemacs user-config

;;; Commentary:
;; Load via (add-to-list 'load-path "~/GNU_files") in user-init
;; and (require 'jal-functions) in user-config

;;; Code:

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

;;;; Keybindings

;; org-mode: date keybinding + ob-mermaid babel integration
(with-eval-after-load 'org
  (when (boundp 'spacemacs/set-leader-keys-for-major-mode)
    (spacemacs/set-leader-keys-for-major-mode 'org-mode
      "oc" 'jal/insert-current-date))
  (require 'ob-mermaid)
  (add-to-list 'org-babel-load-languages '(mermaid . t))
  (org-babel-do-load-languages 'org-babel-load-languages org-babel-load-languages)
  (setq ob-mermaid-cli-path (executable-find "mmdc")))

(with-eval-after-load 'latex
  (when (boundp 'spacemacs/set-leader-keys-for-major-mode)
    (spacemacs/set-leader-keys-for-major-mode 'latex-mode
      "oc" 'jal/insert-current-date)))

;; Mermaid in markdown
(with-eval-after-load 'markdown-mode
  (when (boundp 'spacemacs/set-leader-keys-for-major-mode)
    (spacemacs/set-leader-keys-for-major-mode 'markdown-mode
      "cm" 'jal/markdown-compile-mermaid-at-point)))

(provide 'jal-functions)
;;; jal-functions.el ends here
