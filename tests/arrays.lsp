;-*- Mode: Lisp -*-
;;;; Arrays: the actual element type of an array, whatever its rank and
;;;; adjustability.

(in-package :cl-test)

;;; ------------------------------------------------------------------
;;; The actual array element type is the upgraded element type, for
;;; every rank and adjustability.
;;;
;;; Spec: 15.1.2.1 Array Upgrading -- "The upgraded array element type
;;;   of the expressed array element type becomes the actual array
;;;   element type of the array that is created. ... The upgraded array
;;;   element type T2 of a type T1 is a function only of T1 itself; that
;;;   is, it is independent of any other property of the array for which
;;;   T2 will be used, such as rank, adjustability, fill pointers, or
;;;   displacement."  https://metaspec.dev/chap-15.html#sec_15_1_2_1
;;; and ARRAY-ELEMENT-TYPE.  https://metaspec.dev/f_array-element-type.html
;;; ANSI-TEST checks specialized element types mostly on simple vectors.

(defparameter *addendum-element-types*
  '(bit (unsigned-byte 8) (unsigned-byte 16) (unsigned-byte 32) (signed-byte 8)
    (signed-byte 32) fixnum single-float double-float character base-char t))

(defparameter *addendum-dimensions* '((3) (2 2) (2 2 2) ()))

(deftest addendum.array-element-type.upgraded-for-every-shape
  (let ((bad '()))
    (dolist (et *addendum-element-types* (nreverse bad))
      (let ((want (upgraded-array-element-type et)))
        (dolist (dims *addendum-dimensions*)
          (dolist (options '(() (:adjustable t)))
            (let ((got (array-element-type
                        (apply #'make-array dims :element-type et options))))
              (unless (addendum-type-equal got want)
                (push (list et dims options got want) bad))))
          ;; a fill pointer and displacement need rank one
          (when (= (length dims) 1)
            (dolist (a (list (make-array 3 :element-type et :fill-pointer 1)
                             (make-array 2 :element-type et
                                           :displaced-to (make-array 3 :element-type et))))
              (unless (addendum-type-equal (array-element-type a) want)
                (push (list et :rank-one-variant (array-element-type a) want) bad))))))))
  nil)

;;; ------------------------------------------------------------------
;;; An element of the array's type, stored, is read back.
;;;
;;; Spec: AREF -- "Accesses the array element specified by the
;;;   subscripts"; (setf aref) stores into it.  https://metaspec.dev/f_aref.html

(defparameter *addendum-element-samples*
  '((bit 1) ((unsigned-byte 8) 200) ((unsigned-byte 16) 60000)
    ((unsigned-byte 32) 4000000000) ((signed-byte 8) -100) ((signed-byte 32) -2000000000)
    (single-float 2.5) (double-float -2.5d0) (character #\x) (base-char #\y) (t :any)))

(deftest addendum.aref.store-and-read-back
  (let ((bad '()))
    (dolist (entry *addendum-element-samples* (nreverse bad))
      (destructuring-bind (et value) entry
        (dolist (dims *addendum-dimensions*)
          (dolist (options '(() (:adjustable t)))
            (let* ((a (apply #'make-array dims :element-type et options))
                   (subscripts (make-list (length dims) :initial-element 1)))
              (setf (apply #'aref a subscripts) value)
              (unless (eql (apply #'aref a subscripts) value)
                (push (list et dims options (apply #'aref a subscripts)) bad))))))))
  nil)
