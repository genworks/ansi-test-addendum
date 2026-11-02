;-*- Mode: Lisp -*-
;;;; The compiler: conforming code it must accept, and evaluation order
;;;; it must keep.

(in-package :cl-test)

;;; ------------------------------------------------------------------
;;; A type declaration that would be violated only on a path not taken
;;; does not stop the code from compiling or running.
;;;
;;; Spec: Declaration TYPE -- "During the execution of any reference
;;;   to the declared variable within the scope of the declaration, the
;;;   consequences are undefined if the value of the declared variable
;;;   is not of the declared type."  https://metaspec.dev/d_type.html
;;; It is the value during execution that matters, so code that never
;;; gives the variable a wrong value is conforming.
;;; A compiler that unboxes the constant of each branch for the
;;; declared type can fail on the other branch's constant at compile
;;; time.  ANSI-TEST's declaration tests use values of the declared
;;; type on every branch.

(defparameter *addendum-branch-cases*
  '(((lambda (x) (let ((a (if x 1 nil))) (declare (fixnum a)) (+ a 1))) 2)
    ((lambda (x) (let ((a (if x 1 :k))) (declare (fixnum a)) (+ a 1))) 2)
    ((lambda (x) (let ((a (if x 1 'foo))) (declare (fixnum a)) (+ a 1))) 2)
    ((lambda (x) (let ((a (if x 1 '(1 2)))) (declare (fixnum a)) (+ a 1))) 2)
    ((lambda (x) (let ((a (if x 1 "s"))) (declare (fixnum a)) (+ a 1))) 2)
    ((lambda (x) (let ((a (if x 1 2.5))) (declare (fixnum a)) (+ a 1))) 2)
    ((lambda (x) (let ((d (if x 2.5d0 'none))) (declare (double-float d)) (* d 2))) 5.0d0)
    ((lambda (x) (let ((d (if x 2.5d0 nil))) (declare (double-float d)) (* d 2))) 5.0d0)
    ((lambda (x) (let ((d (if x 2.5 nil))) (declare (single-float d)) (* d 2))) 5.0)
    ((lambda (x) (+ (the fixnum (if x 1 nil)) 1)) 2)))

(deftest addendum.compile.declared-type-on-untaken-branch
  (loop for (form want) in *addendum-branch-cases*
        for got = (handler-case (funcall (compile nil form) t)
                    (error (e) (list :error (type-of e))))
        unless (eql got want) collect (list form got))
  nil)

;;; LOOP's destructuring with OF-TYPE lists, compiled.
;;; Spec: 6.1.1.7 Destructuring -- "d-type-spec ... (fixnum fixnum)"
;;;   https://metaspec.dev/chap-6.html#sec_6_1_1_7
(deftest addendum.compile.loop-destructuring-of-type
  (list (funcall (compile nil '(lambda () (loop with (a b) of-type (fixnum fixnum) = '(3 4)
                                                return (+ a b)))))
        (funcall (compile nil '(lambda () (loop with (x y) of-type (double-float double-float)
                                                  = '(1d0 2d0) return (+ x y)))))
        (funcall (compile nil '(lambda () (loop for (a b) of-type (fixnum fixnum)
                                                  in '((1 2) (3 4)) sum (* a b))))))
  (7 3.0d0 14))

;;; ------------------------------------------------------------------
;;; The function form of MAPCAR and MAPC is evaluated once, before the
;;; list forms.
;;;
;;; Spec: 3.1.2.1.2.3 Function Forms -- "The subforms in the cdr of the
;;;   original form are evaluated in left-to-right order in the current
;;;   lexical and dynamic environments."
;;;   https://metaspec.dev/chap-3.html#sec_3_1_2_1_2_3
;;; A compiler that open-codes MAPCAR may re-evaluate the function form
;;; per element, or evaluate it after the lists.  ANSI-TEST's ordering
;;; tests for these run interpreted unless *COMPILE-TESTS* is set.

(deftest addendum.compile.mapcar-function-form-once-and-first
  (funcall (compile nil '(lambda ()
                          (let ((n 0) (log '()))
                            (list (mapcar (progn (incf n) #'1+) '(1 2 3))
                                  n
                                  (progn (mapc (progn (push :fn log) #'identity)
                                               (progn (push :list log) '(1 2)))
                                         (reverse log))
                                  (let ((m 0))
                                    (mapcar (progn (incf m) #'list) '(1 2) '(3 4))
                                    m))))))
  ((2 3 4) 1 (:fn :list) 1))
