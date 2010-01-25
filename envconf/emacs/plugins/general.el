
;; general
(menu-bar-mode nil)
(tool-bar-mode nil)
(scroll-bar-mode nil)
(setq line-number-mode t)
(setq column-number-mode t)
(setq-default show-trailing-whitespace t)
(fset 'yes-or-no-p 'y-or-n-p)
(global-font-lock-mode t)
(show-paren-mode t)
(blink-cursor-mode -1)
;(normal-erase-is-backspace-mode)



;(add-hook 'text-mode-hook
;	  (lambda ()
;	    ;stuff
;	    ))

;; M-x name-last-kbd-macro, avec C-x ( et ) et e

;; other modes that may or may not be available
(require 'inf-haskell nil t)
