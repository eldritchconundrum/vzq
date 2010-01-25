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

