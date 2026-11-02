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

;;; ------------------------------------------------------------------
;;; A stored element reads back, or the store is refused.
;;;
;;; Spec: Glossary, array element type -- "(of an array) 1. a type
;;;   associated with the array, and of which all elements of the array
;;;   are constrained to be members."
;;;   https://metaspec.dev/chap-26.html#gl_array_element_type
;;; and AREF: SETF of AREF replaces an element with the new value.
;;;   https://metaspec.dev/f_aref.html
;;; An implementation may refuse an object outside the element type, but
;;; not keep another value in its place: 256 stored in an
;;; (UNSIGNED-BYTE 8) array and read back as 0.  ANSI-TEST stores values
;;; of the element type, and tries out-of-range ones in few shapes.

(defun addendum-store-shapes (et)
  "Arrays of element type ET: simple, adjustable, fill-pointered and
displaced vectors, and a simple and an adjustable 2x2 array."
  (list (make-array 3 :element-type et)
        (make-array 3 :element-type et :adjustable t)
        (make-array 3 :element-type et :fill-pointer 1)
        (make-array 2 :element-type et :displaced-to (make-array 3 :element-type et))
        (make-array '(2 2) :element-type et)
        (make-array '(2 2) :element-type et :adjustable t)))

(deftest addendum.aref.store-reads-back-or-is-refused
  (let ((bad '()))
    (dolist (entry '((bit 2 -1) ((unsigned-byte 8) 256 -1) ((unsigned-byte 16) 65536 -1)
                     ((unsigned-byte 32) 4294967296 -1) (character 65))
                   (nreverse bad))
      (destructuring-bind (et &rest values) entry
        (dolist (a (addendum-store-shapes et))
          (dolist (v values)
            (let* ((subs (make-list (array-rank a) :initial-element 0))
                   (r (handler-case (progn (setf (apply #'aref a subs) v)
                                           (apply #'aref a subs))
                        (error () :refused))))
              (unless (or (eq r :refused) (eql r v))
                (push (list et (array-dimensions a) (adjustable-array-p a) v r) bad))))))))
  nil)

;;; ------------------------------------------------------------------
;;; SUBSEQ, COPY-SEQ and REVERSE keep the element type, whatever the
;;; vector's shape.
;;;
;;; Spec: SUBSEQ -- "If sequence is a vector, the result is a fresh
;;;   simple array of rank one that has the same actual array element
;;;   type as sequence."  https://metaspec.dev/f_subseq.html
;;;   COPY-SEQ in the same words.  https://metaspec.dev/f_copy-seq.html
;;;   REVERSE -- "For reverse, if sequence is a vector, the result is a
;;;   fresh simple array of rank one that has the same actual array
;;;   element type as sequence."  https://metaspec.dev/f_reverse.html
;;; ANSI-TEST checks the result's element type mostly from simple
;;; vectors; here from adjustable, fill-pointered and displaced ones.

(defparameter *addendum-element-type-samples*
  '((bit 1) ((unsigned-byte 8) 200) ((unsigned-byte 16) 60000)
    ((unsigned-byte 32) 4000000000) ((signed-byte 8) -100) (character #\a) (t x)))

(deftest addendum.subseq.element-type-of-every-shape
  (let ((bad '()))
    (dolist (entry *addendum-element-type-samples* (nreverse bad))
      (destructuring-bind (et x) entry
        (let ((want (upgraded-array-element-type et)))
          (dolist (v (list (make-array 4 :element-type et :initial-element x :adjustable t)
                           (make-array 4 :element-type et :initial-element x :fill-pointer 4)
                           (make-array 4 :element-type et
                                         :displaced-to (make-array 5 :element-type et
                                                                     :initial-element x)
                                         :displaced-index-offset 1)))
            (dolist (op (list (cons 'subseq (lambda (s) (subseq s 1 3)))
                              (cons 'copy-seq #'copy-seq)
                              (cons 'reverse #'reverse)))
              (let ((r (funcall (cdr op) v)))
                (unless (and (typep r '(simple-array * (*)))
                             (addendum-type-equal (array-element-type r) want)
                             (every (lambda (e) (eql e x)) r))
                  (push (list et (car op) (adjustable-array-p v)
                              (array-has-fill-pointer-p v) (array-element-type r))
                        bad)))))))))
  nil)

;;; ------------------------------------------------------------------
;;; ADJUST-ARRAY keeps the element type.
;;;
;;; Spec: ADJUST-ARRAY -- "Element-type specifies the type of the
;;;   elements of the resulting array."  https://metaspec.dev/f_adjust-array.html
;;; and 15.1.2.1, quoted above: the upgraded element type is independent
;;;   of adjustability and displacement.
;;; Adjusted with no :ELEMENT-TYPE, with the array's own, and to a
;;; displaced array; growing with an :INITIAL-ELEMENT, since reading an
;;; uninitialized element is undefined.  ANSI-TEST adjusts arrays of few
;;; specialized element types.  Each case runs isolated (ADDENDUM-ISOLATED):
;;; on one implementation growing a simple vector threw a Java exception
;;; that ended the thread.

(deftest addendum.adjust-array.keeps-element-type
  (let ((bad '()))
    (dolist (entry *addendum-element-type-samples* (nreverse bad))
      (destructuring-bind (et x) entry
        (let ((want (upgraded-array-element-type et)))
          (flet ((check (label thunk)
                   (let ((r (addendum-isolated
                             (lambda ()
                               (handler-case (funcall thunk)
                                 (error (e) (list :error (type-of e))))))))
                     (unless (and (arrayp r)
                                  (addendum-type-equal (array-element-type r) want)
                                  (eql (row-major-aref r 0) x))
                       (push (list et label (if (arrayp r) (array-element-type r) r)) bad)))))
            (check :simple-longer
                   (lambda () (adjust-array (make-array 2 :element-type et :initial-element x)
                                            4 :initial-element x)))
            (check :adjustable-longer
                   (lambda () (adjust-array (make-array 2 :element-type et :initial-element x
                                                         :adjustable t)
                                            4 :initial-element x)))
            (check :own-element-type
                   (lambda () (adjust-array (make-array 2 :element-type et :initial-element x
                                                         :adjustable t)
                                            4 :element-type et :initial-element x)))
            (check :to-displaced
                   (lambda () (adjust-array (make-array 2 :element-type et :initial-element x)
                                            3 :displaced-to (make-array 3 :element-type et
                                                                          :initial-element x))))
            (check :two-dimensional-longer
                   (lambda () (adjust-array (make-array '(2 2) :element-type et
                                                              :initial-element x :adjustable t)
                                            '(3 3) :initial-element x))))))))
  nil)
