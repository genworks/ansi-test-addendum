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
;;; does not share it: at its default policy, a compiled store of the
;;; constant 256 into a vector whose simple type is declared reads back
;;; 0 (and -1 reads back 255), while a store of a value it cannot see
;;; at compile time is refused.  SBCL 2.6.10 refuses every way.  So the
;;; test is contested, and it stores the constant through every path: a
;;; full call, a compiled function with the array's type declared, for
;;; a simple vector one with its exact simple type declared, and a
;;; compiled form that makes the vector itself.

(defun addendum-store-shapes (et)
  "Arrays of element type ET: simple, adjustable, fill-pointered and
displaced vectors, and a simple and an adjustable 2x2 array."
  (list (make-array 3 :element-type et)
        (make-array 3 :element-type et :adjustable t)
        (make-array 3 :element-type et :fill-pointer 1)
        (make-array 2 :element-type et :displaced-to (make-array 3 :element-type et))
        (make-array '(2 2) :element-type et)
        (make-array '(2 2) :element-type et :adjustable t)))

(defun addendum-store-paths (et v)
  "Ways to store V into the first element of an array A of element type
ET and read it back, each a (LABEL . FUNCTION) with FUNCTION taking A.
The :SIMPLE and :LITERAL paths apply only to a simple vector, and the
:LITERAL one makes a simple vector of its own in the compiled form and
stores V as a constant."
  (list (cons :call (lambda (a)
                      (setf (row-major-aref a 0) v)
                      (row-major-aref a 0)))
        (cons :declared (compile nil `(lambda (a)
                                        (declare (type (array ,et) a))
                                        (setf (row-major-aref a 0) ,v)
                                        (row-major-aref a 0))))
        (cons :simple (compile nil `(lambda (a)
                                      (declare (type (simple-array ,et (*)) a))
                                      (setf (aref a 0) ,v)
                                      (aref a 0))))
        (cons :literal (compile nil `(lambda (a)
                                       (declare (ignore a))
                                       (let ((b (make-array 3 :element-type ',et)))
                                         (setf (aref b 0) ,v)
                                         (aref b 0)))))))

(deftest addendum.aref.store-reads-back-or-is-refused
  (let ((bad '()))
    (dolist (entry '((bit 2 -1) ((unsigned-byte 8) 256 -1) ((unsigned-byte 16) 65536 -1)
                     ((unsigned-byte 32) 4294967296 -1) (character 65))
                   (nreverse bad))
      (destructuring-bind (et &rest values) entry
        (dolist (v values)
          (let ((paths (addendum-store-paths et v)))
            (dolist (a (addendum-store-shapes et))
              (dolist (path paths)
                (unless (and (member (car path) '(:simple :literal))
                             (not (typep a `(simple-array ,et (*)))))
                  (let ((r (handler-case (funcall (cdr path) a)
                             (error () :refused))))
                    (unless (or (eq r :refused) (eql r v))
                      (push (list et (array-dimensions a) (adjustable-array-p a)
                                  (car path) v r)
                            bad)))))))))))
  nil)
