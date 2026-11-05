;-*- Mode: Lisp -*-
;;;; Loads the addendum's tests into ANSI-TEST's harness.  Load this
;;;; after ANSI-TEST's gclload1.lsp (which defines RT and CL-TEST) and
;;;; instead of gclload2.lsp; then (rt:do-tests) runs the addendum alone.
;;;; The tests under contested/ (readings of the standard that SBCL and
;;;; CCL do not share) load too when CL-USER::*ADDENDUM-CONTESTED* is
;;;; true.

(in-package :cl-user)

(defvar *addendum-contested* nil)

(let ((here (make-pathname :name nil :type nil :version nil :defaults *load-truename*)))
  (flet ((load-dir (dir names)
           (let ((d (merge-pathnames (make-pathname :directory (list :relative dir)
                                                    :name nil :type nil :version nil)
                                     here)))
             (dolist (name names)
               (load (make-pathname :name name :type "lsp" :defaults d))))))
    (load-dir "tests" '("aux" "numbers" "types" "arrays" "printer" "reader" "backquote"
                        "clos" "structures" "packages" "compiler"))
    (when *addendum-contested*
      (load-dir "contested" '("format" "backquote")))))
