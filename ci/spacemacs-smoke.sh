#!/usr/bin/env bash
# Load Spacemacs in batch mode with the tracked .spacemacs and fail if it
# reports any package install or load errors.
#
# Usage: ci/spacemacs-smoke.sh EMACS_BIN SPACEMACS_DIR
#
# ~/.spacemacs must already point at the repository's .spacemacs. The first run
# installs every package the configured layers need, so it needs network access.
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "usage: $0 EMACS_BIN SPACEMACS_DIR" >&2
    exit 64
fi
emacs_bin="$1"
spacemacs_dir="$2"

# GNU and NonGNU ELPA are hosted by the FSF and have had day-long outages.
# When they are unreachable, install those two archives from a mirror and
# require their GPG signatures, so the mirror cannot substitute packages
# (MELPA publishes no signatures and keeps the default check).
elpa_mirror=""
if ! curl -fsS -o /dev/null --connect-timeout 20 -m 60 \
    https://elpa.gnu.org/packages/archive-contents; then
    elpa_mirror="${SPACEMACS_SMOKE_ELPA_MIRROR:-https://mirrors.tuna.tsinghua.edu.cn/elpa}"
    echo "GNU ELPA is unreachable; using signed archives from $elpa_mirror" >&2
fi
export SPACEMACS_SMOKE_ACTIVE_ELPA_MIRROR="$elpa_mirror"

# Batch mode normally suppresses user init, so load Spacemacs explicitly.
# Spacemacs logs package install failures and carries on, so fail on its
# error count rather than only on a crash.
"$emacs_bin" --batch \
    --eval '(setq vterm-always-compile-module t)' \
    --eval "(advice-add 'pdf-tools-install :filter-args (lambda (args) (cons t (cdr args))))" \
    --eval '(let ((mirror (getenv "SPACEMACS_SMOKE_ACTIVE_ELPA_MIRROR")))
              (when (and mirror (not (string-empty-p mirror)))
                (setq package-check-signature t
                      package-unsigned-archives (list "melpa" "spacelpa"))
                (advice-add (quote configuration-layer/initialize) :before
                            (lambda (&rest _)
                              (dolist (name (list "gnu" "nongnu"))
                                (setf (alist-get name configuration-layer-elpa-archives
                                                 nil nil (function equal))
                                      (format "%s/%s/" mirror name)))))))' \
    --load "$spacemacs_dir/init.el" \
    --eval '(when (bound-and-true-p configuration-layer-error-count)
              (message "Spacemacs reported %d install/load errors" configuration-layer-error-count)
              (kill-emacs 1))' \
    --eval '(progn (message "Spacemacs smoke passed") (kill-emacs 0))'
