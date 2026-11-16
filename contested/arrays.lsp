;-*- Mode: Lisp -*-
;;;; Arrays: what a store of an object outside the element type may do.
;;;; A reading the reference implementations do not share.

(in-package :cl-test)

;;; ------------------------------------------------------------------
;;; A stored element reads back, or the store is refused.
;;;
;;; Spec: Glossary, array element type -- "(of an array) 1. a type
;;;   associated with the array, and of which all elements of the array
;;;   are constrained to be members."
;;;   https://metaspec.dev/chap-26.html#gl_array_element_type
;;; and AREF, whose new-element is "an object" and whose Exceptional
;;;   Situations are "None".  https://metaspec.dev/f_aref.html
;;; The standard constrains the elements and says nothing about a store
;;; of a non-member.  The reading here is that an implementation may
;;; refuse such a store but not keep another value in its place: 256
;;; stored in an (UNSIGNED-BYTE 8) array and read back as 0.  CCL 1.14
;;; does not share it: a compiled store into an array whose type is
;;; declared keeps 256 as 0 at its default policy, while the full call
;;; (SETF (APPLY #'AREF ...)) is refused.  SBCL 2.6.10 refuses both.
;;; So the test is contested, and it stores through every path: a full
;;; call, a compiled function with the array's type declared, and for a
;;; simple vector one with its exact simple type declared.

(defun addendum-store-shapes (et)
  "Arrays of element type ET: simple, adjustable, fill-pointered and
displaced vectors, and a simple and an adjustable 2x2 array."
  (list (make-array 3 :element-type et)
        (make-array 3 :element-type et :adjustable t)
        (make-array 3 :element-type et :fill-pointer 1)
        (make-array 2 :element-type et :displaced-to (make-array 3 :element-type et))
        (make-array '(2 2) :element-type et)
        (make-array '(2 2) :element-type et :adjustable t)))

(defun addendum-store-paths (et)
  "Ways to store V into the first element of an array A of element type
ET and read it back, each a (LABEL . FUNCTION) with FUNCTION taking A
and V; the :SIMPLE path applies only to a simple vector."
  (list (cons :call (lambda (a v)
                      (setf (row-major-aref a 0) v)
                      (row-major-aref a 0)))
        (cons :declared (compile nil `(lambda (a v)
                                        (declare (type (array ,et) a))
                                        (setf (row-major-aref a 0) v)
                                        (row-major-aref a 0))))
        (cons :simple (compile nil `(lambda (a v)
                                      (declare (type (simple-array ,et (*)) a))
                                      (setf (aref a 0) v)
                                      (aref a 0))))))

(deftest addendum.aref.store-reads-back-or-is-refused
  (let ((bad '()))
    (dolist (entry '((bit 2 -1) ((unsigned-byte 8) 256 -1) ((unsigned-byte 16) 65536 -1)
                     ((unsigned-byte 32) 4294967296 -1) (character 65))
                   (nreverse bad))
      (destructuring-bind (et &rest values) entry
        (let ((paths (addendum-store-paths et)))
          (dolist (a (addendum-store-shapes et))
            (dolist (path paths)
              (unless (and (eq (car path) :simple)
                           (not (typep a `(simple-array ,et (*)))))
                (dolist (v values)
                  (let ((r (handler-case (funcall (cdr path) a v)
                             (error () :refused))))
                    (unless (or (eq r :refused) (eql r v))
                      (push (list et (array-dimensions a) (adjustable-array-p a)
                                  (car path) v r)
                            bad)))))))))))
  nil)
