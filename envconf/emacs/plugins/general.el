
;; general
(menu-bar-mode -1) ;; emacs24
(tool-bar-mode -1) ;; emacs24
(scroll-bar-mode -1) ;; emacs24
(setq line-number-mode t)
(setq column-number-mode t)
(setq-default show-trailing-whitespace t)
(fset 'yes-or-no-p 'y-or-n-p)
(global-font-lock-mode t)
(show-paren-mode t)
(blink-cursor-mode -1)
;(normal-erase-is-backspace-mode)

(set-cursor-color "#be369c")
(set-foreground-color "white")
(set-background-color "grey10")

;(add-hook 'text-mode-hook
;	  (lambda ()
;	    ;stuff
;	    ))

;; M-x name-last-kbd-macro, avec C-x ( et ) et e

;; other modes that may or may not be available
(require 'inf-haskell nil t)

(add-to-list 'load-path "~/.emacs-conf/scala/")
(require 'scala-mode-auto nil t)

(add-to-list 'load-path "~/.emacs-conf/rust-mode/")
(require 'rust-mode)


; nicuveo -- change font size
(defun my/usual-font ()
 (interactive)
 (custom-set-faces
  '(default ((t (:inherit nil :stipple nil :background "black" :foreground "light gray" :slant normal :weight normal :height 90 :width normal))))
  ))

(defun my/stream-font ()
 (interactive)
 (custom-set-faces
  '(default ((t (:inherit nil :stipple nil :background "black" :foreground "light gray" :slant normal :weight normal :height 150 :width normal))))
  ))


;; electric-indent-mode messes with my whitespace in text-mode (it trims before inserting newline when I press enter)
(defun turnoff-electric-indent-mode () (setq electric-indent-mode nil))
(add-hook 'text-mode-hook 'turnoff-electric-indent-mode)
