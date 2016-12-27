;;; find-file-from-selection.el --- open files from the clipboard
;;;                                 content.

;; Copyright (C) 2016  Adam Sjøgren

;; Author: Adam Sjøgren <asjo@koldfront.dk>
;; Keywords: find-file, clipboard, selection
;; Version: 0.1

;; Released under the GPLv2.

;;; Commentary:

;; This library allows you to select some text (in a terminal, using
;; your mouse) representing a file name and optionally a line number
;; and perhaps a column, and having Emacs open the file, jumping to
;; the line, with one keystroke.

;; Usage:

;;   (add-to-list 'load-path "PATHTOFFFS")
;;   (require 'find-file-from-selection)
;;   (define-key global-map (kbd "C-c C-f") 'find-file-from-selection)

;; You should of course `find-file-from-selection` to whatever key you
;; prefer.

;; Supported formats:

;;  filename line N
;;  filename LN

;; Note that if the filename isn't absolute, it will be tried open
;; from cwd, and then relative to the configurable list of directories
;; `find-file-from-selection-directories`, opening the first one
;; matched.

;;; Code:

(require 'find-lisp)

(defvar find-file-from-selection-directories
  '()
  "List of directories to look for files in, when using
  find-file-from-selection. All elements should end in a slash.
  Note that if these directories are large, looking through them
  will probably take quite some time.")

(defvar find-file-from-selection-exclude-directories
  '("~/" (expand-file-name "~/"))
  "List of directories to skip when recursively searching for
   files. Defaults to your home directory, as that probably is large
   and takes a long time to search through.")

(defun find-file-from-selection ()
  "Open file referred to in current selection (clipboard)"
  (interactive)
  (let ((selection (gui-get-selection)))
    (if (not selection)
        (message "Nothing selected")
      (let ((fileinfo (fffs-extract-fileinfo selection)))
        (let ((filename (car fileinfo))
              (linenumber (cadr fileinfo))
              (position (cadr (cdr fileinfo))))
          (if filename
              (progn
                (find-file filename)
                (if linenumber
                    (progn
                      (goto-char (point-min))
                      (forward-line (1- linenumber))
                      (if position
                          (forward-char (1- position)))))
                (message "Found file %s from selection \"%s\"" filename (string-trim selection)))
          (message "Could not match selection \"%s\" to a file" (string-trim selection))))))))

(defun fffs-match-python (selection)
  "Match 'File \"FILE\", line N, in <module>'"
  (if (string-match "\\(?:File \\)?\"\\([^:space].*\\)\", line \\([0-9]+\\)\\(?:, in\\)?" selection)
      (list (match-string 1 selection) (string-to-number (match-string 2 selection)))))
; (fffs-match-python "  File \"/tmp/hep.py\", line 3, in <module>")

(defun fffs-match-ruby (selection)
  "Match 'FILE:N:in `'"
  (if (string-match "\\([^:space].*?\\):\\([0-9]+\\):in" selection)
      (list (match-string 1 selection) (string-to-number (match-string 2 selection)))))
; (fffs-match-ruby "/tmp/hep.rb:3:in `<main>': undefined method `problem' for main:Object (NoMethodError)")

(defun fffs-match-ghc-gcc-clang (selection)
  "Match 'FILE:N:P: error'"
  (if (string-match "\\([^:space].*?\\):\\([0-9]+\\):\\([0-9]+\\)" selection)
      (list (match-string 1 selection) (string-to-number (match-string 2 selection)) (string-to-number (match-string 3 selection)))))
; (fffs-match-ghc-gcc-clang "hep.c:5:16: warning: format ‘%s’ expects argument of type ‘char *’, but argument 2 has type ‘int’ [-Wformat=]")
; (fffs-match-ghc-gcc-clang "hep.hs:2:15: error:")

(defun fffs-match-sh (selection)
  "Match 'FILE: N: FILE:'"
  (if (string-match "\\([^:space].*?\\): \\([0-9]+\\)" selection)
      (list (match-string 1 selection) (string-to-number (match-string 2 selection)))))
; (fffs-match-sh "./demo/sh/test.sh: 7: ./demo/sh/test.sh: Syntax error:")

(defun fffs-match-perl (selection)
  "Match 'TEXT at FILENAME line N.'"
  (if (string-match "\\(?:.* ?at \\)?\\([^[:space:]].*\\)[^,] line \\([0-9]+\\)" selection)
      (list (match-string 1 selection) (string-to-number (match-string 2 selection)))))
; (fffs-match-perl "HERE at /tmp/hep.pl line 6.")
; (fffs-match-perl " at /tmp/hep.pl line 6.")
; (fffs-match-perl "at /tmp/hep.pl line 6.")
; (fffs-match-perl " /tmp/hep.pl line 6.")
; (fffs-match-perl "/tmp/hep.pl line 6.")
; (fffs-match-perl "/tmp/hep.pl line 6")
; (fffs-match-perl "  File \"/tmp/hep.py\", line 3, in <module>")

(defun fffs-match-just-file (selection)
  "Match 'FILE' (just remove any pre/postpended whitespace)."
  (if (string-match "^\\(?:--- \\|\+\+\+ \\)?\\([^[:space:]].*[^[:space:]]\\)$" (string-trim selection))
      (list (match-string 1 selection))))
; (fffs-match-just-file "a/tmp/hep.pl")
; (fffs-match-just-file " hep.pl")
; (fffs-match-just-file "hep.pl ")
; (fffs-match-just-file " hep.pl ")
; (fffs-match-just-file "--- a/feedbase-web/src/Pages.hs\n")

(defvar fffs-match-functions
  '(fffs-match-ghc-gcc-clang
    fffs-match-sh
    fffs-match-perl
    fffs-match-python
    fffs-match-ruby
    fffs-match-just-file)
  "Functions to try and match selection against, in order.")

(defun fffs-extract-fileinfo (selection)
  "Try to interpret string as filename linenumber and position,
   and match it to file in filesystem."
  (let ((funcs fffs-match-functions)
        (func nil)
        (found nil))
    (while (and (not found) (setq func (pop funcs)))
      (setq found (funcall func selection)))
    (if found
        (append (list (fffs-locate-file (car found))) (cdr found)))))
; (fffs-extract-fileinfo "hep.hs:2:15: error:")
; (fffs-extract-fileinfo "--- a/feedbase-web/src/Pages.hs")

(defun fffs-locate-file (filename)
  "Look for a file called `filename`, first just using then name,
   then recursively in the current directory, and finally
   recursively in `find-file-from-selection-directories`."
  (if (file-exists-p filename)
      filename
    (fffs-locate-file-recursively filename)))
; (fffs-locate-file "hep.pl")
; (fffs-locate-file "a/feedbase-web/src/Pages.hs")

(defun fffs-locate-file-recursively (filename)
  "Look for a file called `filename` recursively in the current
   directory and then in `find-file-from-selection-directories`."
  (let ((directories (append (list default-directory) find-file-from-selection-directories))
        (directory nil)
        (found nil))
    (while (and (not found) (setq directory (pop directories)))
      (setq found (fffs-locate-file-recursively-directory directory filename)))
    found))

(defun fffs-locate-file-recursively-directory (directory filename)
  "Look for file called `filename` recursively under `directory`."
  (let ((found nil))
    (if (file-exists-p (concat directory filename))
        (setq found (concat directory filename))
      (if (string-match "/" filename)
          (let ((parts (split-string filename "/")))
            (pop parts)
            (if parts
                (fffs-locate-file-recursively-directory directory (mapconcat 'identity parts "/"))))
        (progn
          (if (and (file-exists-p directory) (not (member directory find-file-from-selection-exclude-directories)))
              (setq found (find-lisp-find-files directory filename)))
          (if found (setq found (pop found)))
          found)))))

(provide 'find-file-from-selection)

;;; find-file-from-selection.el ends here
