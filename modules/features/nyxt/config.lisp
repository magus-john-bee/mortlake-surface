;;; Nyxt configuration — vim keybindings, KeePassXC, search engines.
;;; Loaded from ~/.config/nyxt/config.lisp

(in-package #:nyxt-user)

;; ── Vi keybindings ──────────────────────────────────────────
;; Enable vi-normal-mode as default for all buffers.
;; j/k scroll, h/l history, d delete buffer, o/O open URL, etc.
;; Press 'i' for insert mode, Escape back to normal mode.

(define-configuration input-buffer
  ((default-modes (pushnew 'nyxt/mode/vi:vi-normal-mode %slot-value%))))

(define-configuration prompt-buffer
  ((default-modes (pushnew 'nyxt/mode/vi:vi-insert-mode %slot-value%))))

;; ── Custom vi-normal bindings ───────────────────────────────
;; Extend base-mode with additional vim-style bindings.
(define-configuration base-mode
  ((keyscheme-map
    (define-keyscheme-map
     "my-base" (list :import %slot-value%)
     nyxt/keyscheme:vi-normal
     (list
      ;; Buffer navigation
      "g g" 'nyxt/mode/buffer:switch-buffer
      "g t" 'nyxt:make-window
      ;; Tab/buffer management
      "x" 'nyxt:delete-current-buffer
      ;; Quick URL open
      "o" 'nyxt:set-url
      "O" 'nyxt:set-url-new-buffer
      ;; Search
      "/" 'nyxt/mode/search:search-buffer
      "n" 'nyxt/mode/search:search-next
      "N" 'nyxt/mode/search:search-previous
      ;; Bookmarks
      "m b" 'nyxt/mode/bookmark:bookmark-url
      "m l" 'nyxt/mode/bookmark:list-bookmarks
      ;; Hinting (vimium-style)
      "f" 'nyxt/mode/hint:hint-links
      "F" 'nyxt/mode/hint:hint-links-new-buffer)))))

;; ── KeePassXC integration ───────────────────────────────────
;; Nyxt has built-in KeePassXC support via password-keepassxc.lisp.
;; Requires keepassxc-cli in PATH and a .kdbx database.
;; Uncomment and set the path once the .kdbx is in place:
;;
;; (define-configuration nyxt/mode/password:password-mode
;;   ((nyxt/mode/password:keepassxc-database-path
;;     (make-instance 'nyxt/mode/password:path-password-source
;;                    :path "/path/to/database.kdbx"))))

;; ── Search engines ──────────────────────────────────────────
(define-configuration context-buffer
  ((search-engines
    (list
     (make-instance 'search-engine
                    :shortcut "ddg"
                    :search-url "https://duckduckgo.com/?q=~a"
                    :fallback-url "https://duckduckgo.com/")
     (make-instance 'search-engine
                    :shortcut "g"
                    :search-url "https://google.com/search?q=~a"
                    :fallback-url "https://google.com/")
     (make-instance 'search-engine
                    :shortcut "aw"
                    :search-url "https://wiki.archlinux.org/index.php?search=~a"
                    :fallback-url "https://wiki.archlinux.org/")
     (make-instance 'search-engine
                    :shortcut "nix"
                    :search-url "https://search.nixos.org/packages?query=~a"
                    :fallback-url "https://search.nixos.org/packages")
     (make-instance 'search-engine
                    :shortcut "m"
                    :search-url "https://mynixos.com/search?q=~a"
                    :fallback-url "https://mynixos.com/")
     (make-instance 'search-engine
                    :shortcut "arxiv"
                    :search-url "https://arxiv.org/search/?query=~a&searchtype=all"
                    :fallback-url "https://arxiv.org/")
     (make-instance 'search-engine
                    :shortcut "gh"
                    :search-url "https://github.com/search?q=~a"
                    :fallback-url "https://github.com/")))))

;; ── Ad blocking & tracking ──────────────────────────────────
(define-configuration web-buffer
  ((default-modes
    (pushnew 'nyxt/mode/blocker:blocker-mode %slot-value%))))

(define-configuration web-buffer
  ((default-modes
    (pushnew 'nyxt/mode/reduce-tracking:reduce-tracking-mode %slot-value%))))
