;;; install_all_the_icons_fonts.el --- Install all-the-icons fonts -*- lexical-binding: t; -*-

(require 'package)

;; Use Spacemacs' package dir (elpa/<major.minor>/develop) when it exists, so
;; this doesn't install a second, unmanaged copy under plain elpa/.
(let ((spacemacs-elpa (expand-file-name
                       (format "elpa/%d.%d/develop"
                               emacs-major-version emacs-minor-version)
                       user-emacs-directory)))
  (when (file-directory-p spacemacs-elpa)
    (setq package-user-dir spacemacs-elpa)))

(package-initialize)

(unless (package-installed-p 'all-the-icons)
  (unless (assoc "melpa" package-archives)
    (add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t))
  (unless package-archive-contents
    (package-refresh-contents))
  (package-install 'all-the-icons))

(require 'all-the-icons)
(all-the-icons-install-fonts t)

;;; install_all_the_icons_fonts.el ends here
