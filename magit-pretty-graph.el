;;; -*-coding: utf-8 -*-
;;; magit-pretty-graph.el --- a pretty git graph drawn with Emacs lisp

;; Copyright (C) 2013  George Kettleborough

;; Author: George Kettleborough <g.kettleborough@member.fsf.org>
;; Created: 20130426
;; Version: 0.1.0
;; Status: experimental
;; Package-Requires: ((cl-lib "0.2") (magit "1.2.0"))
;; Homepage: https://github.com/georgek/magit-pretty-graph

;; This file is not part of Magit.
;; This file is not part of GNU Emacs.

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; For a full copy of the GNU General Public License
;; see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; A pretty git graph drawn with Emacs lisp.

;; This isn't ready yet but you can already try it out in a git
;; repository like this:
;;
;;   M-x magit-pg-repo

;;; Code:

(require 'cl-lib)

(defconst magit-pg-command
  (concat "git --no-pager log --date-order --decorate=full "
          "--pretty=format:\"%H%x00%P%x00%h%x00%an%x00%ar%x00%s%x00%d\" "
          "--all -n 100")
  "The command used to fill the raw output buffer.")

(defconst magit-pg-buffer-name "*magit-prettier-graph*"
  "The name of the buffer that the graph gets drawn in.")
(defconst magit-pg-output-buffer-name "*magit-prettier-graph-output*"
  "The name of the buffer where raw output from git goes.")

(defvar magit-pg-trunks nil
  "Holds the current state of trunks while the graph is being drawn.")

(defmacro magit-pg-dolistc (spec &rest body)
  "Loop over a list.
Evaluate BODY with VAR bound to each cons from LIST, in turn.
An implicit nil block is established around the loop.

Modifying cdr's can have unforeseen consequences.  In particular
the loop only terminates when it finds a cdr which is equal to
nil

\(fn (VAR LIST) BODY...)"
  (declare (indent 1))
  `(cl-block nil
     (let ((,(car spec) ,(cadr spec)))
       (while (consp ,(car spec))
         ,@body
         (setq ,(car spec) (rest ,(car spec)))))))

(defmacro magit-pg-stradd (string &rest newstrings)
  (declare (indent 1))
  `(setq ,string (concat ,string ,@newstrings)))

(defmacro magit-pg-with-font-lock-face (face &rest body)
  (declare (indent 1))
  `(let ((beg (point)))
     ,@body
     (put-text-property beg (point) 'font-lock-face ,face)))

(defmacro magit-pg-defchar (name str)
  `(defconst ,name
     (vector
      (propertize ,str 'face 'magit-pg-trunk)
      ,@(mapcar #'(lambda (n)
                    (let ((nstr (number-to-string n)))
                      `(propertize
                        ,str 'face
                        ',(intern (concat "magit-pg-trunk-" nstr)))))
                (list 1 2 3 4 5)))))

(defmacro magit-pg-getchar (name &optional colour)
  (if (null colour)
      `(elt ,(intern (concat "magit-pg-" (symbol-name name))) 0)
    `(elt ,(intern (concat "magit-pg-" (symbol-name name))) ,colour)))

(magit-pg-defchar magit-pg-head "┍")
(magit-pg-defchar magit-pg-node "┝")
(magit-pg-defchar magit-pg-tail "┕")
(magit-pg-defchar magit-pg-commit "◇")
(magit-pg-defchar magit-pg-down "│")
(magit-pg-defchar magit-pg-branchright "├")
(magit-pg-defchar magit-pg-branchleft "┤")
(magit-pg-defchar magit-pg-branchcross "┼")
(magit-pg-defchar magit-pg-branchdown "┬")
(magit-pg-defchar magit-pg-branchup "┴")
(magit-pg-defchar magit-pg-across "─")
(magit-pg-defchar magit-pg-topright "╮")
(magit-pg-defchar magit-pg-bottomright "╯")
(magit-pg-defchar magit-pg-topleft "╭")
(magit-pg-defchar magit-pg-bottomleft "╰")

(defgroup magit-pg-faces nil
  "Customize the appearance of Magit pretty graph."
  :prefix "magit-pg-"
  :group 'faces
  :group 'magit-pg)

(defface magit-pg-author
  '((((class color) (background light))
     :foreground "olive drab")
    (((class color) (background dark))
     :foreground "light green"))
  "Face for the author element of the log output."
  :group 'magit-pg-faces)

(defface magit-pg-date
  '((((class color) (background light))
     :foreground "steel blue")
    (((class color) (background dark))
     :foreground "sky blue"))
  "Face for the date element of the log output."
  :group 'magit-pg-faces)

(defface magit-pg-trunk
  '((((class color) (background light))
     :foreground "black")
    (((class color) (background dark))
     :foreground "white"))
  "Face for drawing trunks."
  :group 'magit-pg-faces)

(defface magit-pg-trunk-1
  '((((class color) (background light))
     :foreground "dark red")
    (((class color) (background dark))
     :foreground "light coral"))
  "Face for drawing trunks."
  :group 'magit-pg-faces)

(defface magit-pg-trunk-2
  '((((class color) (background light))
     :foreground "dark green")
    (((class color) (background dark))
     :foreground "pale green"))
  "Face for drawing trunks."
  :group 'magit-pg-faces)

(defface magit-pg-trunk-3
  '((((class color) (background light))
     :foreground "medium blue")
    (((class color) (background dark))
     :foreground "cyan"))
  "Face for drawing trunks."
  :group 'magit-pg-faces)

(defface magit-pg-trunk-4
  '((((class color) (background light))
     :foreground "dark orange")
    (((class color) (background dark))
     :foreground "gold"))
  "Face for drawing trunks."
  :group 'magit-pg-faces)

(defface magit-pg-trunk-5
  '((((class color) (background light))
     :foreground "purple")
    (((class color) (background dark))
     :foreground "orchid"))
  "Face for drawing trunks."
  :group 'magit-pg-faces)

(defun magit-pg-make-ring (length)
  (let* ((l (make-list length 1))
         (ll (car l)))
    (magit-pg-dolistc (c (cdr l))
      (setcar c (1+ ll))
      (setq ll (car c))
      (when (null (cdr c))
        (setcdr c l)
        (return l)))))

(defconst magit-pg-colour-ring (magit-pg-make-ring 5))

(defconst magit-pg-n-trunk-colours 5)

(defmacro magit-pg-cycle-colour (start n &rest body)
  (declare (indent 2))
  `(progn
     ,@body
     (setq ,start (1+ (mod ,start ,n)))))

(defun magit-pg-next-colour (current &optional n)
  "Returns the next colour in the cycle, or the nth next colour."
  (unless n
    (setq n 1))
  (1+ (mod (+ (1- current) n) magit-pg-n-trunk-colours)))

(defun magit-pg-repo (&optional directory)
  (interactive
   (list (read-directory-name "Repository: ")))
  (with-current-buffer (get-buffer-create
                        magit-pg-output-buffer-name)
    (erase-buffer)
    (cd (or directory default-directory))
    (call-process-shell-command
     magit-pg-command
     nil
     magit-pg-output-buffer-name))
  (magit-pg magit-pg-output-buffer-name)
  (pop-to-buffer magit-pg-buffer-name))

(defun magit-pg-parse-hash (hash-str)
  (let ((hash (make-vector 4 0)))
    (dotimes (i 4)
      (aset hash i
            (string-to-number
             (substring hash-str (* i 10) (+ (* i 10) 10))
             16)))
    hash))

(defun magit-pg-hash (commit)
  (cadr commit))

(defun magit-pg-parents (commit)
  (cddr commit))

(defun magit-pg-shorthash (commit)
  (nth 0 (car commit)))

(defun magit-pg-author (commit)
  (nth 1 (car commit)))

(defun magit-pg-date (commit)
  (nth 2 (car commit)))

(defun magit-pg-message (commit)
  (nth 3 (car commit)))

(defun magit-pg-refs (commit)
  (nth 4 (car commit)))

(defun magit-pg-parse-refs (string)
  (let ((refs (or (string-empty-p string)
                  (split-string (substring string 2 -1)
                                ", " t))))
    (unless refs
      (remq nil (mapcar
                 (lambda (s)
                   (and (not
                         (or (string= s "tag:")
                             (string= s "HEAD")))
                        s))
                 refs)))))

(defun magit-pg-refs-string (commit)
  (let (refs)
    (setq refs (or (string-empty-p (magit-pg-refs commit))
                   (split-string (substring (magit-pg-refs commit) 2 -1)
                                 ", " t)))
    (when (consp refs)
      (concat
       " "
       (mapconcat #'magit-pg-ref-propertize refs " ")))))

(defun magit-pg-ref-propertize (ref)
  (let ((face 'magit-log-head-label-default))
    (cond
     ((string-match-p ".+/.+" ref)
      (setq face 'magit-log-head-label-remote))
     (t
      (setq face 'magit-log-head-label-local)))
    (propertize ref 'face face)))

(defun magit-pg-commit-string (commit)
  (concat
   (propertize (magit-pg-shorthash commit) 'face 'magit-log-sha1)
   (magit-pg-refs commit)
   " ("
   (propertize (truncate-string-to-width
                (magit-pg-author commit)
                16 nil nil "...")
               'face 'magit-pg-author)
   " "
   (propertize (substring (magit-pg-date commit) 0 -4) 'face 'magit-pg-date)
   ") "
   (magit-pg-message commit)))

(defun magit-pg-commit-string-2 (commit)
  (mapconcat
   #'identity
   (list (magit-pg-shorthash commit)
         (magit-pg-author commit)
         (magit-pg-date commit)
         (magit-pg-message commit)
         (magit-pg-refs commit))
   " "))

(defun magit-pg-parse-output (buffer)
  (with-current-buffer buffer
    (when (string= (substring (buffer-string) 0 5) "fatal")
      (error "Git error, see output buffer for details"))
    (let ((commits (mapcar
                    #'(lambda (line)
                        (split-string line "\0" nil))
                    (split-string (buffer-string) "\n" t))))
      (when (string= (substring (caar commits) 0 7) "Commits")
        (pop commits))
      (setq commits
            (mapcar
             #'(lambda (commit)
                 (setq commit (cons (cddr commit) commit))
                 (setcar (cdr commit) (magit-pg-parse-hash (cadr commit)))
                 (setcdr (cdr commit) (mapcar
                                       #'magit-pg-parse-hash
                                       (split-string (caddr commit) " " t)))
                 commit)
             commits)))))

(defun magit-pg-print-commit (commit)
  "Prints a commit node, returns new trunks, destroys trunks input."
  (when (null magit-pg-trunks) (setq magit-pg-trunks (list nil)))
  (let* ((output "")
         (head (not (member (magit-pg-hash commit) magit-pg-trunks)))
         (tail (and (not head) (null (magit-pg-parents commit))))
         (colour 1))
    (when head
      (magit-pg-dolistc (trunkc magit-pg-trunks)
        (cond
         ((null (car trunkc))
          (setcar trunkc (magit-pg-hash commit))
          (return))
         ((null (cdr trunkc))
          (setcdr trunkc (cons (magit-pg-hash commit) nil))
          (return)))))
    (dolist (trunk magit-pg-trunks)
      (magit-pg-cycle-colour colour magit-pg-n-trunk-colours
        (cond
         ((equal trunk (magit-pg-hash commit))
          (cond
           (head
            (magit-pg-stradd output
              (magit-pg-getchar head colour)
              (magit-pg-getchar commit colour)))
           (tail
            (magit-pg-stradd output
              (magit-pg-getchar tail colour)
              (magit-pg-getchar commit colour)))
           (t
            (magit-pg-stradd output
              (magit-pg-getchar node colour)
              (magit-pg-getchar commit colour)))))
         (trunk
          (magit-pg-stradd output
            (magit-pg-getchar down colour)
            " "))
         (t
          (magit-pg-stradd output
            "  ")))))
    (magit-pg-stradd output
      " ")))

(defun magit-pg-n-to-next-parent (trunks parents)
  "Returns number of trunks until next parent."
  (let ((n 0))
    (dolist (trunk (cdr trunks))
      (setq n (1+ n))
      (when (member trunk parents)
        (return)))
    n))

(defun magit-pg-print-merge (commit parents)
  "Prints a merge (if there is one) and returns new trunks (destructively)."
  (let ((output "")
        merge
        (trunk-merges (list)))
    (magit-pg-dolistc (trunkc magit-pg-trunks)
      (when (equal (car trunkc) (magit-pg-hash commit))
        (setcar trunkc (pop parents))
        (setq merge (car trunkc))
        (return)))

    (when (consp parents)
      ;; deal with merge
      (let ((new-parents (cl-set-difference parents magit-pg-trunks
                                            :test #'equal))
            (last-parent)
            (first-parent)
            (colour 1))
        ;; fill in nils and find rightmost parent
        (magit-pg-dolistc (trunkc magit-pg-trunks)
          (cond
           ((eq (car trunkc) merge)
            (or first-parent (setq first-parent (car trunkc)))
            (setq last-parent (car trunkc)))
           ((and (null (car trunkc)) (consp new-parents))
            (setcar trunkc (pop new-parents))
            (or first-parent (setq first-parent (car trunkc)))
            (setq last-parent (car trunkc)))
           ((member (car trunkc) parents)
            (push (car trunkc) trunk-merges)
            (or first-parent (setq first-parent (car trunkc)))
            (setq last-parent (car trunkc)))))
        (when (consp new-parents)
          (setq last-parent (car (last new-parents)))
          (setq magit-pg-trunks (nconc magit-pg-trunks new-parents)))
        ;; draw merge
        (let ((str " ")
              (before-merge t))
          (magit-pg-dolistc (trunkc magit-pg-trunks)
            (magit-pg-cycle-colour colour magit-pg-n-trunk-colours
              (cond
               ((eq first-parent (car trunkc))
                (if (and before-merge (not (eq merge (car trunkc))))
                    (setq str (magit-pg-getchar across colour))
                  (setq str (magit-pg-getchar
                             across
                             (magit-pg-next-colour
                              colour
                              (magit-pg-n-to-next-parent trunkc parents)))))
                (cond
                 ((and before-merge (eq merge (car trunkc)))
                  (setq before-merge nil)
                  (magit-pg-stradd output
                    (magit-pg-getchar branchright colour)
                    str))
                 ((memq (car trunkc) trunk-merges)
                  (magit-pg-stradd output
                    (magit-pg-getchar down colour)
                    (magit-pg-getchar topleft colour)))
                 (t
                  (magit-pg-stradd output
                    (magit-pg-getchar topleft colour)
                    str))))

               ((eq last-parent (car trunkc))
                (setq str " ")
                (cond
                 ((and before-merge (eq merge (car trunkc)))
                  (setq before-merge nil)
                  (magit-pg-stradd output
                    (magit-pg-getchar branchleft colour)
                    str))
                 ((memq (car trunkc) trunk-merges)
                  (setq output (substring output 0 -1))
                  (magit-pg-stradd output
                    (magit-pg-getchar topright colour)
                    (magit-pg-getchar down colour)
                    str))
                 (t
                  (magit-pg-stradd output
                    (magit-pg-getchar topright colour)
                    str))))

               (t
                (cond
                 ((and before-merge (eq merge (car trunkc)))
                  (setq before-merge nil)
                  (magit-pg-stradd output
                    (magit-pg-getchar branchcross colour)
                    str))
                 ((memq (car trunkc) trunk-merges)
                  (if before-merge
                      (progn
                        (setq str (magit-pg-getchar across colour))
                        (magit-pg-stradd output
                          (magit-pg-getchar down colour)
                          (magit-pg-getchar branchdown colour)))
                    (setq str (magit-pg-getchar
                               across
                               (magit-pg-next-colour
                                colour
                                (magit-pg-n-to-next-parent trunkc parents))))
                    (setq output (substring output 0 -1))
                    (magit-pg-stradd output
                      (magit-pg-getchar branchdown colour)
                      (magit-pg-getchar down colour)
                      str)))
                 ((member (car trunkc) parents)
                  (if before-merge
                      (setq str (magit-pg-getchar across colour))
                    (setq str (magit-pg-getchar
                               across
                               (magit-pg-next-colour
                                colour
                                (magit-pg-n-to-next-parent trunkc parents)))))
                  (magit-pg-stradd output
                    (magit-pg-getchar branchdown colour)
                    str))
                 ((car trunkc)
                  (magit-pg-stradd output
                    (magit-pg-getchar down colour)
                    str))
                 (t
                  (magit-pg-stradd output
                    str str)))))))
          ;; draw rest of trunk merges
          (setq str " ")
          (setq before-merge t)
          (setq colour 1)
          (when (consp trunk-merges)
            (magit-pg-stradd output
              " \n")
            (dolist (trunk magit-pg-trunks)
              (magit-pg-cycle-colour colour magit-pg-n-trunk-colours
                (cond
                 ((and before-merge (eq merge trunk))
                  (setq before-merge nil)
                  (magit-pg-stradd output
                    (magit-pg-getchar down colour)
                    str))
                 ((memq trunk trunk-merges)
                  (if before-merge
                      (magit-pg-stradd output
                        (magit-pg-getchar branchright colour)
                        (magit-pg-getchar bottomright colour))
                    (setq output (substring output 0 -1))
                    (magit-pg-stradd output
                      (magit-pg-getchar bottomleft colour)
                      (magit-pg-getchar branchleft colour)
                      str)))
                 (trunk
                  (magit-pg-stradd output
                    (magit-pg-getchar down colour)
                    str))
                 (t
                  (magit-pg-stradd output
                    str str)))))))))
    output))

(defun magit-pg-print-branches ()
  (let ((output "")
        (first t)
        (l nil))
    (magit-pg-dolistc (trunkc magit-pg-trunks)
      ;; find last element with same hash
      (unless (null (car trunkc))
        (magit-pg-dolistc (otrunkc (rest trunkc))
          (when (equal (car trunkc) (car otrunkc))
            (setq l otrunkc)
            (setcar otrunkc 'same)))
        (when l                         ; branch
          (if first
              (setq first nil)
            (magit-pg-stradd output
              " \n"))
          (let ((str " ")
                (colour 1))
            (magit-pg-dolistc (otrunkc magit-pg-trunks)
              (magit-pg-cycle-colour colour magit-pg-n-trunk-colours
                (cond
                 ((equal (car otrunkc) (car trunkc))
                  (setq str (magit-pg-getchar
                             across
                             (magit-pg-next-colour
                              colour (1+ (cl-position 'same (cdr otrunkc))))))
                  (magit-pg-stradd output
                    (magit-pg-getchar branchright colour)
                    str))
                 ((eq (car otrunkc) 'same)
                  (if (not (eq otrunkc l))
                      (progn
                        (setq str (magit-pg-getchar
                                   across
                                   (magit-pg-next-colour
                                    colour (1+ (cl-position 'same
                                                            (cdr otrunkc))))))
                        (magit-pg-stradd output
                          (magit-pg-getchar branchup colour) str))
                    (setq str " ")
                    (magit-pg-stradd output
                      (magit-pg-getchar bottomright colour)
                      str))
                  (setcar otrunkc nil))
                 ((car otrunkc)
                  (magit-pg-stradd output
                    (magit-pg-getchar down colour)
                    str))
                 (t
                  (magit-pg-stradd output
                    str str)))))))
        (setq l nil)))
    output))

(defun magit-pg (buffer)
  (let (output
        (commits (magit-pg-parse-output buffer)))
    (setq magit-pg-trunks (list))
    ;; print graph
    (with-current-buffer (get-buffer-create magit-pg-buffer-name)
      (read-only-mode -1)
      (setq truncate-lines t)
      (erase-buffer)
      (dolist (commit commits)
        ;; print commit
        (insert (magit-pg-print-commit commit)
                (magit-pg-commit-string commit)
                "\n")
        ;; print merge and prepare parents
        (setq output (magit-pg-print-merge commit (magit-pg-parents commit)))
        (unless (string-empty-p output)
          (insert output "\n"))
        ;; print branches and consolidate duplicate parents
        (setq output (magit-pg-print-branches))
        (unless (string-empty-p output)
          (insert output "\n"))
        ;; remove nils at end
        (let ((last magit-pg-trunks))
          (magit-pg-dolistc (trunkc magit-pg-trunks)
            (when (car trunkc)
              (setq last trunkc)))
          (setcdr last nil)))
      (read-only-mode))))

(defun magit-pg-2 (buffer)
  (let (output
        (commits (magit-pg-parse-output buffer)))
    (setq magit-pg-trunks (list))
    ;; print graph
    (with-current-buffer buffer
      (delete-region (point-min) (point-max))
      (dolist (commit commits)
        ;; print commit
        (insert (magit-pg-print-commit commit) " "
                (magit-pg-commit-string-2 commit)
                "\n")
        ;; print merge and prepare parents
        (setq output (magit-pg-print-merge commit (magit-pg-parents commit)))
        (unless (string-empty-p output)
          (insert output "     \n"))
        ;; print branches and consolidate duplicate parents
        (setq output (magit-pg-print-branches))
        (unless (string-empty-p output)
          (insert output "     \n"))
        ;; remove nils at end
        (let ((last magit-pg-trunks))
          (magit-pg-dolistc (trunkc magit-pg-trunks)
            (when (car trunkc)
              (setq last trunkc)))
          (setcdr last nil))))))

(provide 'magit-pretty-graph)
;;; magit-pretty-graph.el ends here
