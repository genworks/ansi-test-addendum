;-*- Mode: Lisp -*-
;;;; Types: TYPE-OF's guarantees over a battery, and SUBTYPEP checked
;;;; against objects instead of against a table of expected answers.

(in-package :cl-test)

(defstruct addendum-struct a)
(defclass addendum-class () ())
(define-condition addendum-condition (error) ())
(deftype addendum-list-alias () 'list)
(deftype addendum-atom-alias () 'atom)

(defun addendum-objects ()
  (list 0 -1 most-positive-fixnum (1+ most-positive-fixnum) (expt 2 70) 1/2
        1.0 1d0 -0.0 #c(1 2) #c(1.0 2.0) #\a #\Space "abc" ""
        (make-string 3 :element-type 'base-char) #(1 2) (make-array 0)
        (make-array 3 :element-type 'bit) #*101 (make-array '(2 2))
        (make-array 3 :adjustable t) (make-array 3 :fill-pointer 1)
        (make-array 3 :displaced-to (make-array 5))
        (make-array 5 :element-type '(unsigned-byte 8))
        (make-array 2 :element-type 'double-float :initial-element 0d0)
        (make-array '() :initial-element 1)
        'foo :kw nil t '(1) '(1 . 2) (make-hash-table) *standard-output*
        (make-string-input-stream "x") (make-broadcast-stream)
        (make-condition 'simple-error) (make-condition 'addendum-condition)
        #'car (lambda (x) x) #'print-object (find-class 'standard-object)
        (make-instance 'addendum-class) (make-addendum-struct) *package*
        #p"/tmp/x.lisp" *random-state* *readtable*))

;;; ------------------------------------------------------------------
;;; TYPE-OF.
;;;
;;; Spec: TYPE-OF -- "the type returned does not involve and, eql,
;;;   member, not, or, satisfies, or values.  For all objects,
;;;   (typep object (type-of object)) returns true. ... (subtypep
;;;   (type-of object) (class-of object)) -> true, true"
;;;   https://metaspec.dev/f_type-of.html
;;; ANSI-TEST checks these per type in scattered tests; this runs all
;;; three over every kind of object at once.

(deftest addendum.type-of.typep
  (loop for x in (addendum-objects)
        unless (typep x (type-of x)) collect (list x (type-of x)))
  nil)

;;; SUBTYPEP returns two values, each a generalized boolean, so any
;;; true value passes; a missing second value does not.
(deftest addendum.type-of.subtypep-class-of
  (loop for x in (addendum-objects)
        unless (multiple-value-bind (sub sure) (subtypep (type-of x) (class-of x))
                 (and sub sure))
          collect (list (type-of x) (class-name (class-of x))
                        (multiple-value-list (subtypep (type-of x) (class-of x)))))
  nil)

(deftest addendum.type-of.no-combinations
  (labels ((bad-p (spec)
             (and (consp spec)
                  (or (member (car spec) '(and eql member not or satisfies values))
                      (some #'bad-p (cdr spec))))))
    (loop for x in (addendum-objects)
          when (bad-p (type-of x)) collect (type-of x)))
  nil)

;;; ------------------------------------------------------------------
;;; SUBTYPEP is sound: a sure true answer is never contradicted by an
;;; object.
;;;
;;; Spec: SUBTYPEP -- "If type-1 is a recognizable subtype of type-2,
;;;   the first value is true", and a true second value says the first
;;;   is certain.  https://metaspec.dev/f_subtypep.html
;;; and 4.2.3 Type Specifiers: a type is a set of objects.
;;;   https://metaspec.dev/chap-4.html#sec_4_2_3
;;; ANSI-TEST checks SUBTYPEP against tables of expected answers, so a
;;; wrong answer for a pair it does not list goes unnoticed; here every
;;; pair of a battery is checked against the objects that inhabit it.

(defun addendum-subtypep-types ()
  (list* 't 'nil 'atom '(not cons) 'cons 'list 'null 'symbol 'keyword 'sequence
         'vector 'string 'fixnum 'number 'function 'hash-table 'standard-object
         'structure-object 'addendum-struct 'addendum-class 'addendum-list-alias
         'addendum-atom-alias '(cons integer) '(cons t t) '(or null cons)
         '(and list (not null)) '(and atom list) '(not atom) '(not list)
         '(not null) '(member nil) '(member nil (a)) '(eql nil) '(eql 1)
         '(or symbol (cons integer)) '(or atom) '(and atom)
         'array 'simple-array 'simple-vector 'simple-string 'base-string
         'simple-base-string 'bit-vector 'simple-bit-vector
         '(array *) '(array t) '(array t (*)) '(array t 1) '(array t (3))
         '(array t 2) '(array * (*)) '(array character (*)) '(array bit (*))
         '(vector *) '(vector t) '(vector t 3) '(vector character)
         '(vector base-char) '(vector bit) '(vector fixnum)
         '(vector (unsigned-byte 8)) '(vector double-float)
         '(simple-array t (*)) '(simple-array * (*)) '(simple-array character (*))
         '(simple-array t (3)) '(simple-array * 2) '(simple-array bit (*))
         '(simple-array (unsigned-byte 8) (*)) '(string 3) '(simple-string 3)
         '(bit-vector 3) '(simple-bit-vector 3) '(array (integer 0 1) (*))
         '(integer 0 10) '(satisfies consp)
         (mapcar #'find-class '(cons list t symbol null sequence addendum-class
                                vector array string bit-vector simple-vector
                                simple-string simple-bit-vector simple-array))))

(deftest addendum.subtypep.sound
  (let ((types (addendum-subtypep-types)) (objects (addendum-objects)) (bad '()))
    (dolist (a types)
      (dolist (b types)
        (multiple-value-bind (sub sure) (subtypep a b)
          (when (and sub sure)
            (dolist (x objects)
              (when (and (typep x a) (not (typep x b)))
                (push (list a b x) bad)))))))
    (subseq (nreverse bad) 0 (min 10 (length bad))))
  nil)

;;; ATOM is (NOT CONS); SUBTYPEP may be unsure of either, but its sure
;;; answers about the two must agree.
;;;
;;; Spec: Type ATOM -- "It is equivalent to (not cons)."
;;;   https://metaspec.dev/t_atom.html

(deftest addendum.subtypep.atom-agrees-with-not-cons
  (let ((bad '()))
    (dolist (ty (addendum-subtypep-types) (nreverse bad))
      (dolist (dir '(:left :right))
        (flet ((ask (x) (multiple-value-list
                         (if (eq dir :left) (subtypep x ty) (subtypep ty x)))))
          (let ((a (ask 'atom)) (b (ask '(not cons))))
            (when (and (second a) (second b) (not (eq (not (first a)) (not (first b)))))
              (push (list dir ty :atom a :not-cons b) bad)))))))
  nil)

;;; ------------------------------------------------------------------
;;; An array of a compound SIMPLE-ARRAY type is a SIMPLE-ARRAY.
;;;
;;; Spec: Type SIMPLE-ARRAY -- the compound type specifier
;;;   (simple-array element-type dimensions) denotes a subset of
;;;   simple-array; SIMPLE-VECTOR, SIMPLE-STRING and SIMPLE-BIT-VECTOR
;;;   are subtypes of it.  https://metaspec.dev/t_simple-array.html
;;; Whether an expressly adjustable array is simple is the
;;; implementation's choice; TYPEP must make the same choice for the
;;; compound types as for the symbol.

(defparameter *addendum-simple-array-types*
  '((simple-array *) (simple-array * (*)) (simple-array t (*))
    (simple-array t (3)) (simple-array t 1) (simple-array t 2)
    (simple-array t (2 2)) (simple-array * 2) (simple-array t ())
    simple-vector (simple-vector 3) simple-string (simple-string 3)
    (simple-array character (*)) simple-bit-vector (simple-bit-vector 3)
    (simple-array (unsigned-byte 8) (*)) (simple-array bit (*))))

(defun addendum-arrays ()
  (list (make-array 3 :adjustable t) (make-array 3 :fill-pointer 2)
        (make-array 3 :displaced-to (make-array 5))
        (make-array 3 :element-type 'character :adjustable t)
        (make-array 3 :element-type 'character :fill-pointer 1)
        (make-array 3 :element-type 'bit :adjustable t)
        (make-array '(2 2) :adjustable t)
        (make-array '(2 2) :displaced-to (make-array 4))
        (make-array '() :adjustable t)
        (make-array 3 :element-type '(unsigned-byte 8) :adjustable t)
        (make-array 3) "abc" #*101 (make-array '(2 2)) (make-array '())))

(defun addendum-compound-simple-misses (typep-fn)
  (let ((bad '()))
    (dolist (x (addendum-arrays) (nreverse bad))
      (dolist (ty *addendum-simple-array-types*)
        (when (and (funcall typep-fn x ty) (not (typep x 'simple-array)))
          (push (list ty (type-of x)) bad))))))

(deftest addendum.typep.compound-simple-array-implies-simple-array
  (addendum-compound-simple-misses #'typep)
  nil)

;;; The same with each type a literal in compiled code, where a
;;; compiler may open-code the test.
(deftest addendum.typep.compound-simple-array-implies-simple-array.compiled
  (addendum-compound-simple-misses
   (lambda (x ty) (funcall (compile nil `(lambda (y) (typep y ',ty))) x)))
  nil)

;;; ------------------------------------------------------------------
;;; The standard array classes and the types of the same names hold the
;;; same arrays, of every rank, adjustability and displacement.
;;;
;;; Spec: 4.3.8 Integrating Types and Classes -- "Every class that has a
;;;   proper name has a corresponding type with the same name." ...
;;;   "Thus the expression (typep object class) evaluates to true if the
;;;   class of object is class itself or a subclass of class."
;;;   https://metaspec.dev/chap-4.html#sec_4_3_8
;;; ANSI-TEST checks TYPEP against classes for a few objects of each
;;; class; arrays of rank zero, of rank three, and displaced arrays are
;;; not among them for the array classes.

(deftest addendum.typep.array-classes-agree-with-types
  (let ((bad '()))
    (dolist (et '(t bit character base-char (unsigned-byte 8) (unsigned-byte 16)
                  (unsigned-byte 32) (signed-byte 8) fixnum single-float double-float)
                (nreverse bad))
      (dolist (dims '(() (3) (2 2) (2 2 2)))
        (dolist (a (list (make-array dims :element-type et)
                         (make-array dims :element-type et :adjustable t)
                         (make-array dims :element-type et
                                          :displaced-to (make-array (reduce #'* dims)
                                                                    :element-type et))))
          (dolist (c '(array simple-array vector simple-vector string simple-string
                       base-string simple-base-string bit-vector simple-bit-vector))
            (unless (eq (not (typep a c)) (not (typep a (find-class c))))
              (push (list et dims (adjustable-array-p a) c) bad)))))))
  nil)
