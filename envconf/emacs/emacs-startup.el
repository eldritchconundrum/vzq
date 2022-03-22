;; sanity
(set-foreground-color "white")
(set-background-color "black")

;; paths and files
(setq backup-directory-alist '(("." . "~/.emacs-conf/backup-files/")))

;; separated file for generated config
(setq custom-file (expand-file-name "~/.emacs-conf/generated-custom-config.el"))
(load-file custom-file)

;; the rest of the conf is in "plugins"
(add-to-list 'load-path "~/.emacs-conf/plugins/")
(load "keybinds.el")
(load "general.el")
(load "gnus.el")




(add-to-list 'load-path "~/emacs-rust-mode/")
(autoload 'rust-mode "rust-mode" nil t)
(add-to-list 'auto-mode-alist '("\\.rs\\'" . rust-mode))


;;; Initialize MELPA
;(require 'package)
;(add-to-list 'package-archives '("melpa" . "http://melpa.milkbox.net/packages/"))
;(unless package-archive-contents (package-refresh-contents))
(package-initialize)

;;; Install fsharp-mode
;(unless (package-installed-p 'fsharp-mode)
;  (package-install 'fsharp-mode))
;(require 'fsharp-mode)




(define-key key-translation-map [dead-grave] (lookup-key key-translation-map "\C-x8`"))
(define-key key-translation-map [dead-acute] (lookup-key key-translation-map "\C-x8'"))
(define-key key-translation-map [dead-circumflex] (lookup-key key-translation-map "\C-x8^"))
(define-key key-translation-map [dead-diaeresis] (lookup-key key-translation-map "\C-x8\""))
(define-key key-translation-map [dead-tilde] (lookup-key key-translation-map "\C-x8~"))
(define-key isearch-mode-map [dead-grave] nil)
(define-key isearch-mode-map [dead-acute] nil)
(define-key isearch-mode-map [dead-circumflex] nil)
(define-key isearch-mode-map [dead-diaeresis] nil)
(define-key isearch-mode-map [dead-tilde] nil)



(unless (version< emacs-version "24")
  (add-to-list 'load-path "~/.emacs.d/zig-mode/")
  (autoload 'zig-mode "zig-mode" nil t)
  (add-to-list 'auto-mode-alist '("\\.zig\\'" . zig-mode)))
