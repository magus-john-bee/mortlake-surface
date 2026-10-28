;;; ~/.config/nyxt/config.lisp — Nyxt's one config file. Yours to hack.
;;;
;;; This is a SEED: copied here ONCE by tmpfiles C+ on first activation.
;;; Edit THIS file (or nyxt --remote -e '...' live); the seed in mortlake
;;; never re-copies over your changes.
;;;
;;; First form loads the mortlake base (/etc/nyxt/config.lisp — read-only,
;;; repoints at every activation). Anything below runs AFTER the base and
;;; overrides it. To make a hack permanent: move it into
;;; modules/features/nyxt/config.lisp, rebuild, delete it from below.

(load "/etc/nyxt/config.lisp")

;; ── hacks below this line ────────────────────────────────────
