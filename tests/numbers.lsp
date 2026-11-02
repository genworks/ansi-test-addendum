;-*- Mode: Lisp -*-
;;;; Numbers: contagion, the fixnum range, and floats at the edges of
;;;; their range.

(in-package :cl-test)

;;; ------------------------------------------------------------------
;;; EXPT of a rational base and a float power.
;;;
;;; Spec: 12.1.4.1 Rule of Float and Rational Contagion -- "when one
;;;   argument is a rational and the other is a float, the rational is
;;;   first converted to a float of the same format."
;;;   https://metaspec.dev/chap-12.html#sec_12_1_4_1
;;; and EXPT: "If b=0 and the real part of x is strictly positive, then
;;;   b^x=0."  https://metaspec.dev/f_exp.html
;;; ANSI-TEST compares such results with =, so returning the rational
;;; 1 or 0 for a float power passes there; the result must be a float.

(deftest addendum.expt.float-power-contagion
  (loop for (base power want) in '((1 2.0 1.0) (1 2.0d0 1.0d0) (1 0.5 1.0)
                                   (1 -3.0d0 1.0d0)
                                   (0 2.0 0.0) (0 2.0d0 0.0d0) (0 0.5 0.0)
                                   (0 1.0d0 0.0d0))
        for got = (funcall 'expt base power)
        unless (eql got want) collect (list base power got))
  nil)

;;; ------------------------------------------------------------------
;;; An integer in the fixnum range is a fixnum.
;;;
;;; Spec: Type FIXNUM -- "A fixnum is an integer whose value is between
;;;   most-negative-fixnum and most-positive-fixnum inclusive."
;;;   https://metaspec.dev/t_fixnum.html
;;; and EQL: two numbers are EQL when of the same type and value.
;;;   https://metaspec.dev/f_eql.html
;;; An implementation that builds a bignum object for a value inside
;;; the range prints it like the fixnum, but TYPEP, EQL, hash tables
;;; and CASE then disagree with it.  ANSI-TEST computes few results
;;; that land in the range from bignum operands.

(defun addendum-near-fixnum-bounds ()
  (let ((p most-positive-fixnum) (n most-negative-fixnum))
    (list p n (1+ p) (1- n) (+ p 2) (- n 2) (* 2 p) (* 2 n)
          (- n) (- (1+ p)) (* p p) 0 1 -1 2 -2 3)))

(defun addendum-fixnum-range-misses (ops)
  ;; every result of OPS over the operands that lands in the fixnum
  ;; range must be of type FIXNUM
  (let ((operands (addendum-near-fixnum-bounds)) (bad '()))
    (dolist (op ops (nreverse bad))
      (dolist (a operands)
        (dolist (b operands)
          (let ((r (funcall (cdr op) a b)))
            (when (and (integerp r)
                       (<= most-negative-fixnum r most-positive-fixnum)
                       (not (typep r 'fixnum)))
              (push (list (car op) a b r) bad))))))))

(defparameter *addendum-integer-ops*
  '((+ . (lambda (a b) (+ a b)))
    (- . (lambda (a b) (- a b)))
    (* . (lambda (a b) (* a b)))
    (truncate . (lambda (a b) (if (zerop b) 0 (values (truncate a b)))))
    (floor . (lambda (a b) (if (zerop b) 0 (values (floor a b)))))
    (rem . (lambda (a b) (if (zerop b) 0 (rem a b))))
    (gcd . (lambda (a b) (gcd a b)))
    (logand . (lambda (a b) (logand a b)))
    (logxor . (lambda (a b) (logxor a b)))
    (ash . (lambda (a b) (if (< -200 b 200) (ash a b) 0)))))

(deftest addendum.integer.fixnum-range-is-fixnum.evaluated
  (addendum-fixnum-range-misses
   (mapcar (lambda (op) (cons (car op) (coerce (cdr op) 'function)))
           *addendum-integer-ops*))
  nil)

(deftest addendum.integer.fixnum-range-is-fixnum.compiled
  (addendum-fixnum-range-misses
   (mapcar (lambda (op) (cons (car op) (compile nil (cdr op))))
           *addendum-integer-ops*))
  nil)

(deftest addendum.integer.fixnum-range-eql
  (let* ((big (- most-negative-fixnum))        ; one past the range, or in it
         (r (funcall '* big -1))               ; = most-negative-fixnum
         (table (make-hash-table)))
    (setf (gethash most-negative-fixnum table) :found)
    (list (eql r most-negative-fixnum)
          (= r most-negative-fixnum)
          (typep r 'fixnum)
          (gethash r table)
          (and (member r (list 0 most-negative-fixnum)) t)))
  (t t t :found t))

;;; ------------------------------------------------------------------
;;; FLOOR, CEILING, TRUNCATE and ROUND of MOST-NEGATIVE-FIXNUM by -1.
;;;
;;; Spec: FLOOR -- the quotient is the integer that the division
;;;   rounds to; the remainder is number minus quotient times divisor.
;;;   https://metaspec.dev/f_floor.html
;;; The quotient (- most-negative-fixnum) is outside the fixnum range
;;; wherever the range is two's-complement; a fixnum division that
;;; overflows returns most-negative-fixnum itself.  The declared case
;;; is conforming: both arguments are fixnums.

(deftest addendum.floor.most-negative-fixnum-by-minus-one
  (let ((n most-negative-fixnum) (want (list (- most-negative-fixnum) 0)) (bad '()))
    (dolist (fn '(floor ceiling truncate round) (nreverse bad))
      (let ((declared (compile nil `(lambda (a b) (declare (fixnum a b))
                                      (multiple-value-list (,fn a b)))))
            (generic (compile nil `(lambda (a b) (multiple-value-list (,fn a b))))))
        (dolist (way (list (cons :funcall (lambda (a b) (multiple-value-list (funcall fn a b))))
                           (cons :compiled generic) (cons :declared declared)))
          (let ((got (funcall (cdr way) n -1)))
            (unless (equal got want) (push (list fn (car way) got) bad)))))))
  nil)

(deftest addendum.mod.most-negative-fixnum-by-minus-one
  (let ((bad '()))
    (dolist (fn '(mod rem) (nreverse bad))
      (let ((declared (compile nil `(lambda (a b) (declare (fixnum a b)) (,fn a b)))))
        (dolist (got (list (funcall fn most-negative-fixnum -1)
                           (funcall declared most-negative-fixnum -1)))
          (unless (eql got 0) (push (list fn got) bad))))))
  nil)

;;; ------------------------------------------------------------------
;;; FLOAT-PRECISION of a denormalized float.
;;;
;;; Spec: FLOAT-PRECISION -- "returns the number of significant radix b
;;;   digits present in float; if float is a float zero, then the
;;;   result is an integer zero."  https://metaspec.dev/f_decode-float.html
;;; K times the least positive float has exactly (integer-length K)
;;; significant bits.  ANSI-TEST checks FLOAT-PRECISION on normalized
;;; floats and zeros only.

(deftest addendum.float-precision.denormalized
  (when (addendum-ieee-denormals-p)
    (loop for (least bits) in (list (list least-positive-double-float 52)
                                    (list least-positive-single-float 23))
          nconc (loop for len from 1 to bits
                      nconc (loop for k in (list (ash 1 (1- len)) (1- (ash 1 len))
                                                 (1+ (ash 1 (1- len))))
                                  for x = (* k least)
                                  unless (and (= (float-precision x) (integer-length k))
                                              (= (float-precision (- x)) (integer-length k)))
                                    collect (list x (float-precision x) (integer-length k))))))
  nil)

;;; ------------------------------------------------------------------
;;; DECODE-FLOAT and INTEGER-DECODE-FLOAT of a denormalized float.
;;;
;;; Spec: DECODE-FLOAT -- "decode-float divides float by an integral
;;;   power of b so as to bring its value between 1/b (inclusive) and 1
;;;   (exclusive), and returns the quotient as the first value"; that
;;;   power is the second value and the sign the third, so the three
;;;   give back the float.  https://metaspec.dev/f_decode-float.html

(deftest addendum.decode-float.denormalized
  (loop for x in (addendum-denormals)
        unless (multiple-value-bind (sig e sign) (decode-float x)
                 (and (<= 1/2 sig) (< sig 1)
                      (= (rational x) (* (rational sign) (rational sig) (expt 2 e)))))
          collect (cons x (multiple-value-list (decode-float x))))
  nil)

(deftest addendum.integer-decode-float.denormalized
  (loop for x in (addendum-denormals)
        unless (multiple-value-bind (m e sign) (integer-decode-float x)
                 (= (rational x) (* sign m (expt 2 e))))
          collect (cons x (multiple-value-list (integer-decode-float x))))
  nil)

;;; ------------------------------------------------------------------
;;; SCALE-FLOAT into and out of the denormalized range.
;;;
;;; Spec: SCALE-FLOAT -- "scale-float returns (* float (expt (float b
;;;   float) integer)), where b is the radix of the floating-point
;;;   representation.  float is not necessarily between 1/b and 1."
;;;   https://metaspec.dev/f_decode-float.html
;;; Each product here is a representable float.  Computing b^integer
;;; as a float first overflows or underflows before the multiply when
;;; integer is near the format's range.

(deftest addendum.scale-float.range-edges
  (if (addendum-ieee-denormals-p)
      (list (= (scale-float 1d0 -1074) least-positive-double-float)
            (= (scale-float least-positive-double-float 1074) 1d0)
            (= (scale-float 1f0 -149) least-positive-single-float)
            (= (scale-float least-positive-single-float 149) 1f0)
            (= (rational (scale-float most-positive-double-float -1074))
               (* (rational most-positive-double-float) (expt 2 -1074)))
            (= (rational (scale-float most-positive-single-float -149))
               (* (rational most-positive-single-float) (expt 2 -149)))
            (= (scale-float least-positive-normalized-double-float 2045)
               (* (rational least-positive-normalized-double-float) (expt 2 2045))))
      (list t t t t t t t))
  (t t t t t t t))
