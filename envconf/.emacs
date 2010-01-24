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
;(normal-erase-is-backspace-mode)
(setq backup-directory-alist '(("." . "~/.emacs-backup-files/")))
(add-to-list 'load-path "~/.emacs.d/plugins/")

;; M-x name-last-kbd-macro, avec C-x ( et ) et e

;; key bindings
;(global-set-key "^[[4~" 'end-of-line);end
;(global-set-key "^[[5~" 'View-scroll-page-backward);page up
;(global-set-key "^[[6~" 'View-scroll-page-forward);page down
(global-set-key "[1;5D" 'backward-word);ctrl+left
(global-set-key "[1;5C" 'forward-word);ctrl+right
(global-set-key "[1;5A" 'backward-paragraph);ctrl+up
(global-set-key "[1;5B" 'forward-paragraph);ctrl+down

(global-set-key (kbd "<f9>") 'compile)
(global-set-key (kbd "<f8>") 'next-error)

;; gnus
;(setq user-full-name "DefaultName")
;(setq gnus-nntp-server "news.example.com")
;(setq gnus-posting-styles
;      '((".*"
;         (name "DefaultName")
;         ;(signature-file "~/.signature")
;         (address "example@example.com")
;         )))
;(setq smtpmail-local-domain "example.com")
;(setq message-cite-function
;      'message-cite-original-without-signature)
;(setq message-signature (lambda ()
;                          (shell-command-to-string "~/bin/signature.rb")))
;(add-hook 'gnus-group-mode-hook 'gnus-topic-mode)

(require 'inf-haskell)
(custom-set-variables
  ;; custom-set-variables was added by Custom.
  ;; If you edit it by hand, you could mess it up, so be careful.
  ;; Your init file should contain only one such instance.
  ;; If there is more than one, they won't work right.
 '(inhibit-startup-screen t))
(custom-set-faces
  ;; custom-set-faces was added by Custom.
  ;; If you edit it by hand, you could mess it up, so be careful.
  ;; Your init file should contain only one such instance.
  ;; If there is more than one, they won't work right.
 )
