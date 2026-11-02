;-*- Mode: Lisp -*-
;;;; CLOS: long-form method combination options given by variables.

(in-package :cl-test)

;;; ------------------------------------------------------------------
;;; DEFINE-METHOD-COMBINATION's :ORDER is a form, evaluated where the
;;; lambda-list variables are bound.
;;;
;;; Spec: DEFINE-METHOD-COMBINATION -- "The :order option specifies the
;;;   order of methods.  The order argument is a form that evaluates to
;;;   :most-specific-first or :most-specific-last."  The standard's own
;;;   example writes (primary (and) :order order :required t) with ORDER
;;;   an &optional parameter of the combination.
;;;   https://metaspec.dev/m_define-method-combination.html
;;; ANSI-TEST's :ORDER tests give a constant, so an implementation that
;;; evaluates the form once, at definition time, passes them; here the
;;; ordinary case, a lambda-list variable, decides the order per
;;; generic function.  The definitions are evaluated inside the tests
;;; so that a failure to define is a failed test rather than a load
;;; error.

(deftest addendum.define-method-combination.order-from-variable
  (progn
    (eval '(define-method-combination addendum-collect
               (&optional (order :most-specific-first))
             ((primary (addendum-collect) :order order :required t))
             `(list ,@(mapcar (lambda (m) `(call-method ,m)) primary))))
    (eval '(defgeneric addendum-collect-first (x)
             (:method-combination addendum-collect)))
    (eval '(defgeneric addendum-collect-last (x)
             (:method-combination addendum-collect :most-specific-last)))
    (eval '(defmethod addendum-collect-first addendum-collect ((x integer)) :integer))
    (eval '(defmethod addendum-collect-first addendum-collect ((x number)) :number))
    (eval '(defmethod addendum-collect-last addendum-collect ((x integer)) :integer))
    (eval '(defmethod addendum-collect-last addendum-collect ((x number)) :number))
    (list (funcall 'addendum-collect-first 1)
          (funcall 'addendum-collect-last 1)))
  ((:integer :number) (:number :integer)))

;;; The same with the order chosen by an expression over the variable.
(deftest addendum.define-method-combination.order-from-expression
  (progn
    (eval '(define-method-combination addendum-collect-rev (&optional reverse)
             ((primary (addendum-collect-rev)
                       :order (if reverse :most-specific-last :most-specific-first)))
             `(list ,@(mapcar (lambda (m) `(call-method ,m)) primary))))
    (eval '(defgeneric addendum-collect-rev-gf (x)
             (:method-combination addendum-collect-rev t)))
    (eval '(defmethod addendum-collect-rev-gf addendum-collect-rev ((x integer)) :integer))
    (eval '(defmethod addendum-collect-rev-gf addendum-collect-rev ((x number)) :number))
    (funcall 'addendum-collect-rev-gf 1))
  (:number :integer))
