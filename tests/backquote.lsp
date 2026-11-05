;-*- Mode: Lisp -*-
;;;; Backquote: what a template evaluates to.
;;;;
;;;; The cases are the portable part of quasiquote-test.lisp in
;;;; fare-quasiquote, Copyright (c) 2002-2020 Fahree Reedaw
;;;; <fare@tunes.org>, MIT license, which carries cases from SBCL's
;;;; tests/backq.impure.lisp.  That file also checks how fare-quasiquote
;;;; reads and prints a form; only the values are portable, so only the
;;;; values are here, a few adapted to bind their variables.
;;;;
;;;; Why ANSI-TEST does not catch these: its backquote tests
;;;; (printer/print-backquote.lsp) print a quoted template and read it
;;;; back, so the template is never evaluated, and
;;;; SET-SYNTAX-FROM-CHAR.BACKQUOTE evaluates only `,x.  No test compares
;;;; the value of a vector template or of a nested backquote.  EGCL
;;;; 0.0.11 returns `#(a ,b) with the comma unprocessed.

(defpackage "ADDENDUM-BACKQUOTE"
  (:use "COMMON-LISP"))

(in-package "ADDENDUM-BACKQUOTE")

;;; What the templates refer to.  They are read and evaluated in this
;;; package, with the standard readtable.

(defparameter a '(vector 0))
(defparameter b 11)
(defparameter c (list 22 33))
(defparameter d (list 44 55))
(defparameter x 1)
(defparameter y 2)
(defparameter *k '((list :x x) (list :y y)))
(defparameter *qq* '(*rr* *ss*))
(defparameter *rr* '(3 5))
(defparameter *ss* '(4 6))
(defun *rr* (x) (reduce #'* x))
(defparameter *x* '(a b))
(defparameter *y* '(c))
(defparameter *p* '(append *x* *y*))
(defparameter *q* '((append *x* *y*) (list 'sqrt 9)))
(defparameter *r* '(append *x* *y*))
(defparameter *s* '((append *x* *y*)))

(defun read-here (string)
  (let ((*package* (find-package "ADDENDUM-BACKQUOTE"))
        (*readtable* (copy-readtable nil))
        (*read-eval* t))
    (read-from-string string)))

(in-package :cl-test)

(defun addendum-backquote-mismatches (cases)
  "CASES are (TEMPLATE EVALS EXPECTED): TEMPLATE read and evaluated EVALS
times must be EQUALP to EXPECTED read.  Both are strings, read in the
package ADDENDUM-BACKQUOTE.  Returns what did not hold."
  (loop for (template evals expected) in cases
        for got = (handler-case
                      (let ((v (addendum-backquote::read-here template)))
                        (dotimes (i evals) (setf v (eval v)))
                        (list :value v))
                    (serious-condition (e) (list :error (type-of e))))
        unless (and (eq (first got) :value)
                    (equalp (second got)
                            (addendum-backquote::read-here expected)))
          collect (list template got)))

;;; ------------------------------------------------------------------
;;; Lists: commas and splices.
;;;
;;; Spec: 2.4.6 Backquote -- "`(x1 x2 x3 ... xn . atom) may be
;;;   interpreted to mean (append [ x1] [ x2] [ x3] ... [ xn] (quote
;;;   atom))", with "[form] is interpreted as (list `form)", "[,form] is
;;;   interpreted as (list form)" and "[,@form] is interpreted as form".
;;;   https://metaspec.dev/chap-2.html#sec_2_4_6

(deftest addendum.backquote.lists
  (addendum-backquote-mismatches
   '(("`a" 1 "a")
     ("`(1 2 3)" 1 "(1 2 3)")
     ("`(a ,b)" 1 "(a 11)")
     ("`(1 ,b)" 1 "(1 11)")
     ("`(,'foo ,b)" 1 "(foo 11)")
     ("`(a ,@c)" 1 "(a 22 33)")
     ("`(,@c)" 1 "(22 33)")
     ("`(a ,b ,@c)" 1 "(a 11 22 33)")
     ("`(foobar a b ,c ,'(e f g) d ,@'(e f g) (h i j) ,@c)" 1
      "(foobar a b (22 33) (e f g) d e f g (h i j) 22 33)")))
  nil)

;;; ------------------------------------------------------------------
;;; A dotted tail, an atom or a comma.
;;;
;;; Spec: 2.4.6 Backquote -- the case above, and "`(x1 x2 x3 ... xn .
;;;   ,form) may be interpreted to mean (append [ x1] [ x2] [ x3] ...
;;;   [ xn] form)".  `(x ... . ,@form) has undefined consequences, so it
;;;   is not tested.
;;;   https://metaspec.dev/chap-2.html#sec_2_4_6

(deftest addendum.backquote.dotted-tails
  (addendum-backquote-mismatches
   '(("`(a . ,b)" 1 "(a . 11)")
     ("`(a ,@c . 4)" 1 "(a 22 33 . 4)")
     ("`(a ,b ,@c . ,d)" 1 "(a 11 22 33 44 55)")
     ("`(,@c . ,d)" 1 "(22 33 44 55)")))
  nil)

;;; ------------------------------------------------------------------
;;; Vector templates.
;;;
;;; Spec: 2.4.6 Backquote -- "`#(x1 x2 x3 ... xn) may be interpreted to
;;;   mean (apply #'vector `(x1 x2 x3 ... xn))."
;;;   https://metaspec.dev/chap-2.html#sec_2_4_6
;;; The last case's vector comes from #., so it reaches the backquote as
;;; a vector object and not as #( syntax; it is a general vector, which
;;; "`basic is the same as 'basic" leaves to this rule too.  ABCL and
;;; CMUCL signal an error on it.  #n( under backquote is left out: the
;;; standard does not say when the length applies, and implementations
;;; split three ways on it (fare-quasiquote's README has the table).

(deftest addendum.backquote.vectors
  (addendum-backquote-mismatches
   '(("`#()" 1 "#()")
     ("`#(a ,b)" 1 "#(a 11)")
     ("`#(,@c)" 1 "#(22 33)")
     ("`#.#(1 2 3)" 1 "#(1 2 3)")))
  nil)

;;; ------------------------------------------------------------------
;;; ,. gives the value ,@ gives.
;;;
;;; Spec: 2.4.6 Backquote -- "Anywhere ``,@'' may be used, the syntax
;;;   ``,.'' may be used instead to indicate that it is permissible to
;;;   operate destructively on the list structure produced by the form
;;;   following the ``,.'' (in effect, to use nconc instead of append)."
;;;   https://metaspec.dev/chap-2.html#sec_2_4_6
;;; Permissible, so whether the list changed is not checked: SBCL, CCL
;;; and ECL change it, Clasp does not.

(deftest addendum.backquote.nsplice
  (addendum-backquote-mismatches
   '(("(let ((c (list 2 3)) (d (list 44 55))) `(x ,b ,@a ,.c ,.d))" 1
      "(x 11 vector 0 2 3 44 55)")))
  nil)

;;; ------------------------------------------------------------------
;;; Nested backquotes, evaluated as many times as they are deep.
;;;
;;; Spec: 2.4.6 Backquote -- "If the backquote syntax is nested, the
;;;   innermost backquoted form should be expanded first.  This means
;;;   that if several commas occur in a row, the leftmost one belongs
;;;   to the innermost backquote."
;;;   https://metaspec.dev/chap-2.html#sec_2_4_6
;;; A value after one evaluation would be the implementation's own
;;; representation of the inner backquote, so only the last value is
;;; compared.  What a splice under an inner backquote may do when it
;;; yields several forms is in contested/backquote.lsp; here the forms
;;; are one, or stand where every interpretation the standard lists
;;; agrees.  The table is SBCL's.  dotcl 0.1.36 leaks UNQUOTE-SPLICING
;;; into ``(foo ,@',@*s*).

(deftest addendum.backquote.nested
  (addendum-backquote-mismatches
   '(("``a" 2 "a")
     ("`,`a" 1 "a")
     ("``(a ,b)" 2 "(a 11)")
     ("```(,,a ,',',b)" 3 "(#(0) 11)")
     ("``,,`,3" 2 "3")
     ("``(,,*qq*)" 2 "(24)")
     ("``(,,@*qq*)" 2 "((3 5) (4 6))")
     ("``(foo ,,*p*)" 2 "(foo (a b c))")
     ("``(foo ,',*r*)" 2 "(foo (append *x* *y*))")
     ("``(foo ,',@*s*)" 2 "(foo (append *x* *y*))")
     ("``(foo ,@,*p*)" 2 "(foo a b c)")
     ("``(foo ,@',*r*)" 2 "(foo append *x* *y*)")
     ("``(foo ,@',@*s*)" 2 "(foo append *x* *y*)")))
  nil)
