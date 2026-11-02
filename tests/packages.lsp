;-*- Mode: Lisp -*-
;;;; DEFPACKAGE: options that may be repeated.

(in-package :cl-test)

;;; ------------------------------------------------------------------
;;; Every DEFPACKAGE option but :SIZE (and :DOCUMENTATION) may appear
;;; more than once, and each occurrence counts.
;;;
;;; Spec: DEFPACKAGE -- "All options except :size can appear more than
;;;   once."  and "An error of type program-error should be signaled if
;;;   :size or :documentation appears more than once."
;;;   https://metaspec.dev/m_defpackage.html
;;; ANSI-TEST repeats :USE, :SHADOW and :EXPORT; a DEFPACKAGE that keeps
;;; only the last :NICKNAMES clause passes it.

(deftest addendum.defpackage.repeated-nicknames
  (unwind-protect
       (progn
         (eval '(defpackage "ADDENDUM-PKG-1" (:use)
                 (:nicknames "ADDENDUM-PKG-A") (:nicknames "ADDENDUM-PKG-B")))
         (sort (copy-list (package-nicknames "ADDENDUM-PKG-1")) #'string<))
    (when (find-package "ADDENDUM-PKG-1") (delete-package "ADDENDUM-PKG-1")))
  ("ADDENDUM-PKG-A" "ADDENDUM-PKG-B"))

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
