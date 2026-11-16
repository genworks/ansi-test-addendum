;-*- Mode: Lisp -*-
;;;; DEFPACKAGE: options that may be repeated.

(in-package :cl-test)

;;; ------------------------------------------------------------------
;;; A DEFPACKAGE option other than :SIZE and :DOCUMENTATION may appear
;;; more than once, and each occurrence counts.
;;;
;;; Spec: DEFPACKAGE, Syntax -- "{(:intern {symbol-name}*)}* |" and
;;;   "{(:import-from package-name {symbol-name}*)}* |": the option
;;;   itself is starred, so it may repeat.  "An error of type
;;;   program-error should be signaled if :size or :documentation
;;;   appears more than once."  https://metaspec.dev/m_defpackage.html
;;;   (The metaspec's text also says "All options except :size can
;;;   appear more than once."; the CLHS has no such sentence, and the
;;;   test rests on the syntax, which both give.)
;;; ANSI-TEST repeats :NICKNAMES (DEFPACKAGE.2B), :USE, :SHADOW and
;;; :EXPORT; :INTERN and :IMPORT-FROM are repeated here.

(deftest addendum.defpackage.repeated-intern-and-import
  (unwind-protect
       (progn
         (eval '(defpackage "ADDENDUM-PKG-2" (:use)
                 (:intern "X1") (:intern "X2")
                 (:import-from "COMMON-LISP" "CAR") (:import-from "COMMON-LISP" "CDR")))
         (list (nth-value 1 (find-symbol "X1" "ADDENDUM-PKG-2"))
               (nth-value 1 (find-symbol "X2" "ADDENDUM-PKG-2"))
               (eq (find-symbol "CAR" "ADDENDUM-PKG-2") 'car)
               (eq (find-symbol "CDR" "ADDENDUM-PKG-2") 'cdr)))
    (when (find-package "ADDENDUM-PKG-2") (delete-package "ADDENDUM-PKG-2")))
  (:internal :internal t t))
