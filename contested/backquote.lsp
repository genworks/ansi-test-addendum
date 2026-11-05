;-*- Mode: Lisp -*-
;;;; Backquote: a splice under an inner backquote that yields several
;;;; forms.  The helper and the variables are in tests/backquote.lsp.

(in-package :cl-test)

;;; ------------------------------------------------------------------
;;; Several forms spliced into an inner backquote's template.
;;;
;;; Spec: 2.4.6 Backquote -- "If the backquote syntax is nested, the
;;;   innermost backquoted form should be expanded first."  With
;;;   "[,@form] is interpreted as form", ``(f ,@,@*k) expands first to
;;;   (append (list 'f) ,@*k), and the outer backquote then splices in
;;;   each form of *k, which gives the values below.
;;;   https://metaspec.dev/chap-2.html#sec_2_4_6
;;; But the same section says "An implementation is free to interpret a
;;; backquoted form F1 as any form F2 that, when evaluated, will produce
;;; a result that is the same under equal", and lists (list* (cons a
;;; '(b)) c d) among the legitimate readings of `((,a b) ,c ,@d).  An
;;; inner LIST* takes the forms as separate arguments, the last alone as
;;; the tail, and an inner CONS takes only two.
;;;
;;; CONTESTED: SBCL 2.6.10 passes.  CCL 1.14 and ECL 26.5.5 fail the
;;; three ,@,@ cases: ``(f ,@,@*k) gives (F (:X 1) :Y 2), which is the
;;; LIST* reading, and ``(,@,@*qq*) signals an error.  ABCL 1.9.3 and
;;; CMUCL 21f fail the ,,@ case with a wrong argument count, which is
;;; the CONS reading.  fare-quasiquote's tests note that the ,@,@ cases
;;; "did not work" there at one time.  Kept out of the default run;
;;; CONTESTED=1 loads it.

(deftest addendum.backquote.splice-several-forms
  (addendum-backquote-mismatches
   '(("``(f ,@,@*k)" 2 "(f :x 1 :y 2)")
     ("``(foo ,@,@*q*)" 2 "(foo a b c sqrt 9)")
     ("``(,@,@*qq*)" 2 "(3 5 4 6)")
     ("``(,,@(list 1 2 3) 10)" 2 "(1 2 3 10)")))
  nil)
