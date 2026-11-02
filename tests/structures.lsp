;-*- Mode: Lisp -*-
;;;; DEFSTRUCT: typed structures and their predicate option.

(in-package :cl-test)

;;; ------------------------------------------------------------------
;;; An unnamed typed structure accepts (:PREDICATE NIL).
;;;
;;; Spec: DEFSTRUCT, :predicate -- "If the argument is provided and is
;;;   nil, no predicate is defined.  A predicate can be defined only if
;;;   the structure is named; if :type is supplied and :named is not
;;;   supplied, then :predicate must either be unsupplied or have the
;;;   value nil."  https://metaspec.dev/m_defstruct.html
;;; An implementation that rejects any :PREDICATE option on an unnamed
;;; typed structure passes ANSI-TEST's typed-structure tests, which
;;; leave the option out.

(deftest addendum.defstruct.typed-unnamed-predicate-nil
  (progn
    (eval '(defstruct (addendum-typed-list (:type list) (:predicate nil)) a b))
    (eval '(defstruct (addendum-typed-vector (:type vector) (:predicate nil)) a b))
    (list (funcall 'make-addendum-typed-list :a 1 :b 2)
          (coerce (funcall 'make-addendum-typed-vector :a 1 :b 2) 'list)
          (fboundp 'addendum-typed-list-p)
          (fboundp 'addendum-typed-vector-p)))
  ((1 2) (1 2) nil nil))

;;; Named typed structures with (:PREDICATE NIL) define no predicate
;;; either, and keep their name slot.
(deftest addendum.defstruct.typed-named-predicate-nil
  (progn
    (eval '(defstruct (addendum-named-list (:type list) :named (:predicate nil)) a))
    (list (funcall 'make-addendum-named-list :a 1)
          (fboundp 'addendum-named-list-p)))
  ((addendum-named-list 1) nil))
