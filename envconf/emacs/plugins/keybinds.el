
(defun start-end-kbd-macro ()
  "Starts or end a new macro recording."
  (interactive)
  (if defining-kbd-macro (end-kbd-macro) (start-kbd-macro nil)))


;; global key bindings

;(global-set-key "^[[4~" 'end-of-line);end
;(global-set-key "^[[5~" 'View-scroll-page-backward);page up
;(global-set-key "^[[6~" 'View-scroll-page-forward);page down
(global-set-key "[1;5D" 'backward-word);ctrl+left
(global-set-key "[1;5C" 'forward-word);ctrl+right
(global-set-key "[1;5A" 'backward-paragraph);ctrl+up
(global-set-key "[1;5B" 'forward-paragraph);ctrl+down

(global-set-key [C-tab]  'other-window)

(global-set-key (kbd "<f4>")  'kill-this-buffer)
(global-set-key (kbd "<f9>")  'compile)
(global-set-key (kbd "<f8>")  'next-error)
(global-set-key (kbd "<f12>") 'call-last-kbd-macro)
(global-set-key [C-f12]       'start-end-kbd-macro)


(global-set-key [mouse-4]  '(lambda nil (interactive) (scroll-up 2)))
(global-set-key [mouse-5]  '(lambda nil (interactive) (scroll-down 2)))

