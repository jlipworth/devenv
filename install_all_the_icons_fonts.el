;;; install_all_the_icons_fonts.el --- Install all-the-icons fonts -*- lexical-binding: t; -*-

(require 'package)

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
