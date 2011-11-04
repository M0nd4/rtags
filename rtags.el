;; (defun rtags-setup-hooks () (interactive)
;;   (remove-hook 'after-save-hook 'rtags-sync-all-open-files)
;;   (remove-hook 'find-file-hooks 'rtags-sync-all-open-files)
  ;; (add-hook 'after-save-hook 'rtags-sync-all-open-files)
  ;; (add-hook 'find-file-hooks 'rtags-sync-all-open-files)
  ;; )

(defgroup rtags nil
  "Minor mode for rtags."
  :group 'tools
  :prefix "rtags-")

(defcustom rtags-enable t
  "Whether or rtags is enabled"
  :type 'boolean
  :group 'rtags)

(defun rtags-log (log)
  (save-excursion
    (set-buffer (get-buffer-create "*RTags Log*"))
    (goto-char (point-max))
    (insert "**********************************\n" log "\n")
    )
  )

(defvar last-rtags-update-process nil)
(defun rtags-update ()
  (interactive)
  (if (executable-find "rb")
      (progn
        (if (and last-rtags-update-process (eq (process-status last-rtags-update-process) 'run))
            (kill-process last-rtags-update-process))
        (setq last-rtags-update-process (start-process "rtags-update" nil "rb" "-u"))))
  nil)

(defun rtags-goto-location(location)
  (let (line column)
    (string-match "\\(.*\\):\\([0-9]+\\):\\([0-9]+\\)" location)
;    (message (concat "rtags-goto-location " location (if (match-beginning 1) "yes" "no")))
    (if (match-beginning 1)
        (progn
          (setq line (string-to-int (match-string 2 location)))
          (setq column (string-to-int (match-string 3 location)))
          (find-file (match-string 1 location))
          (goto-char (point-min))
          (forward-line (- line 1))
          (forward-char (- column 1))
          t)
      nil)
    )
  )

(defun rtags-find-symbol-at-point(&optional pos)
  (interactive)
  (let ((bufname (buffer-file-name))
        (line (int-to-string (line-number-at-pos pos)))
        (column nil))
    (save-excursion
      (if pos
          (goto-char pos))
      (if (looking-at "[0-9A-Za-z_~#]")
          (progn
            (while (and (> (point) 1) (looking-at "[0-9A-Za-z_~#]"))
              (backward-char))
            (if (not (looking-at "[0-9A-Za-z_~#]"))
                (forward-char))
            (setq column (int-to-string (- (point) (point-at-bol) -1))))))
    (with-temp-buffer
      (rtags-log (concat (executable-find "rc") " --follow-symbol " bufname ":" line ":" column ":"))
      (call-process (executable-find "rc") nil (list t nil) nil "--follow-symbol" (concat bufname ":" line ":" column ":"))
      (rtags-log (buffer-string))
      (rtags-goto-location (buffer-string)))
    )
  )

(defun rtags-find-references-at-point()
  (interactive)
  (rtags-find-references-at-point-internal "-r")
  )

(defun rtags-find-references ()
  (interactive)
  (unless (rtags-find-references-at-point)
    (message "no"))
  )

(defun rtags-complete (string predicate code)
  (let ((completions))
    (with-temp-buffer
      (rtags-log (concat (executable-find "rc") " -S -n -l " string))
      (call-process (executable-find "rc") nil (list t nil) nil "-S" "-n" "-l" string)
      (rtags-log (buffer-string))
      (setq 'completions (split-string (buffer-string) "\n" t)))))
      ;; (all-completion string completions))))
      ;; (cond ((eq code nil)
      ;;        (try-completion string completions predicate))
      ;;       ((eq code t)
      ;;        (all-completions string completions predicate))
      ;;       ((eq code 'lambda)
      ;;        (if (intern-soft string completions) t nil))))))

(defun rtags-find-references-at-point-internal(mode)
  (let ((bufname (buffer-file-name))
        (line (int-to-string (line-number-at-pos)))
        (column nil)
        (previous (current-buffer)))
    (save-excursion
      (if (looking-at "[0-9A-Za-z_~#]")
          (progn
            (while (and (> (point) 1) (looking-at "[0-9A-Za-z_~#]"))
              (backward-char))
            (if (not (looking-at "[0-9A-Za-z_~#]"))
                (forward-char))
            (setq column (int-to-string (- (point) (point-at-bol) -1))))))
    (if (get-buffer "*Rtags-Complete*")
        (kill-buffer "*Rtags-Complete*"))
    (set-buffer (generate-new-buffer "*Rtags-Complete*"))
    (rtags-log (concat (executable-find "rc") " " mode " " bufname ":" line ":" column ":"))
    (call-process (executable-find "rc") nil (list t nil) nil mode (concat bufname ":" line ":" column ":"))
    (rtags-log (buffer-string))
    (if (= (point-min) (point-max))
        (progn
;          (kill-buffer "*Rtags-Complete*")
          (set-buffer previous)
          nil)
      (progn
        (if (= (count-lines (point-min) (point-max)) 1)
            (rtags-goto-location (buffer-string))
          (progn
            (goto-char (point-min))
            (compilation-mode)
            t))
        ))
    ))

(defun rtags-find-symbol-internal (p switch)
  (let (tagname prompt input completions previous)
    (setq tagname (gtags-current-token))
    (setq previous (current-buffer))
    (if tagname
        (setq prompt (concat p ": (default " tagname ") "))
      (setq prompt (concat p ": ")))
    (with-temp-buffer
      (rtags-log (concat (executable-find "rc") " -l \"\""))
      (call-process (executable-find "rc") nil (list t nil) nil "-l" "")
      (rtags-log (buffer-string))
      (setq completions (split-string (buffer-string) "\n" t)))
      ;; (setq completions (split-string "test1" "test1()")))
    (setq input (completing-read prompt completions nil nil nil gtags-history-list))
    (if (not (equal "" input))
        (setq tagname input))
    (if (get-buffer "*Rtags-Complete*")
        (kill-buffer "*Rtags-Complete*"))
    (switch-to-buffer (generate-new-buffer "*Rtags-Complete*"))
    (rtags-log (concat (executable-find "rc") " " switch " " tagname))
    (call-process (executable-find "rc") nil (list t nil) nil switch tagname)
    (rtags-log (buffer-string))
    (if (= (point-min) (point-max))
        (progn
;          (kill-buffer "*Rtags-Complete*")
          (switch-to-buffer previous))
      (if (= (count-lines (point-min) (point-max)) 1)
          (rtags-goto-location (buffer-string))
        (progn
          (goto-char (point-min))
          (compilation-mode))))
    ))

(defun rtags-find-symbol-prompt ()
  (interactive)
  (rtags-find-symbol-internal "Find symbol" "-s"))

(defun rtags-find-symbol ()
  (interactive)
  (cond ((rtags-find-symbol-at-point) t)
        ((and (string-equal "#include " (buffer-substring (point-at-bol) (+ (point-at-bol) 9)))
              (rtags-find-symbol-at-point (+ (point-at-bol) 1)))
         t)
        (t (rtags-find-symbol-prompt)))
  )

(defun rtags-find-refererences-prompt ()
  (interactive)
  (rtags-find-symbol-internal "Find references" "-r"))


(defun get-match-string (n)
  (buffer-substring (match-beginning n) (match-end n)))

(defun rtags-complete-files (string predicate code)
  (let ((complete-list (make-vector 63 0)))
    (with-temp-buffer
      ;; (call-process (executable-find "rb") nil (list t nil) nil "-P" string)
      (call-process (executable-find "rc") nil t nil "-n" "-P" string)
      (goto-char (point-min))
      (let ((match (if (equal "" string) "\./\\(.*\\)" (concat ".*\\(" string ".*\\)"))))
        (while (not (eobp))
          (looking-at match)
          (intern (match-string 1) complete-list)
          (forward-line))))
    (cond ((eq code nil)
           (try-completion string complete-list predicate))
          ((eq code t)
           (all-completions string complete-list predicate))
          ((eq code 'lambda)
           (if (intern-soft string complete-list) t nil)))))

(defun rtags-goto-file()
  (interactive)
  (goto-char (point-min))
  (let ((line (buffer-substring (point-at-bol) (point-at-eol))))
    (message line)
    (if (file-exists-p line)
        (progn
          (kill-buffer (current-buffer))
          (find-file line))
      )
    )
  )

(defvar rtags-last-buffer nil)
(defun rtags-remove-completions-buffer ()
  (interactive)
  (kill-buffer (current-buffer))
  (switch-to-buffer rtags-last-buffer))

(defun rtags-find-files ()
   (interactive)
   (let ((tagname (gtags-current-token))
         (input (completing-read "Find files: " 'rtags-complete-files nil nil nil gtags-history-list)))
     (setq rtags-last-buffer (current-buffer))
     (unless (equal "" input)
       (progn
         (set-buffer (generate-new-buffer "*Completions*"))
         (call-process (executable-find "rc") nil t nil "-P" input)
         (if (= (point-min) (point-max))
             (rtags-remove-completions-buffer)
           (progn
             (if (= (count-lines (point-min) (point-max)) 1)
                 (rtags-goto-file)
               (progn
                 (switch-to-buffer (current-buffer))
                 (setq buffer-read-only t)
                 (goto-char (point-min))
                 (local-set-key (kbd "q") 'rtags-remove-completions-buffer)
                 (local-set-key (kbd "RET") 'rtags-goto-file))
               )
             )
           )
         )
       )
     )
   )

(provide 'rtags)

(defun compl (string predicate code)
  (let ((complete-list (make-vector 63 0)))
    (save-excursion
      (goto-char (point-min))
      (message (buffer-string))
      (while (not (eobp))
        (intern (buffer-substring (point-at-bol) (point-at-eol)) complete-list)
        (forward-line)))
    (cond ((eq code nil)
           (try-completion string complete-list predicate))
          ((eq code t)
           (all-completions string complete-list predicate))
          ((eq code 'lambda)
           (if (intern-soft string complete-list) t nil)))))

(defun foo() (interactive)
  (message "got: " (completing-read "foo: " 'compl nil nil nil nil (word-at-point)))
  )