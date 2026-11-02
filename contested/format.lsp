;-*- Mode: Lisp -*-
;;;; FORMAT ~F: rounding of the float's own value.

(in-package :cl-test)

;;; ------------------------------------------------------------------
;;; ~,dF rounds the value of the argument to d fractional digits.
;;;
;;; Spec: 22.3.3.1 Tilde F -- "a sequence of digits, containing a
;;;   single embedded decimal point, is printed; this represents the
;;;   magnitude of the value of arg times 10^k, rounded to d fractional
;;;   digits.  When rounding up and rounding down would produce printed
;;;   values equidistant from the scaled value of arg, then the
;;;   implementation is free to use either one."
;;;   https://metaspec.dev/chap-22.html#sec_22_3_3_1
;;; The value of a float is the binary fraction it holds, so 2.675d0
;;; (which is 2.67499999999999982236431605997495353221893310546875)
;;; prints with ~,2F as 2.67.  Rounding the float's shortest decimal
;;; printed form instead (2.675, then 2.68) passes every ANSI-TEST
;;; ~F case.  Exact ties of the binary value are left out, since
;;; either result is allowed there.
;;;
;;; CONTESTED: SBCL 2.6.10 and CCL 1.14 both round some floats' printed
;;; digits rather than their values (both print 3077.4f0 with ~,4F as
;;; 3077.4000, whose value is 3077.39990234375; CCL prints 9.995f0 with
;;; ~,2F as 10.00), so they read "the value of arg" as its printed
;;; value.  Kept out of the default run; CONTESTED=1 loads it.

(defun addendum-exact-f (x d)
  ;; the digits of |x| rounded to D places, as ~,dF prints them
  (multiple-value-bind (int frac)
      (floor (round (* (abs (rational x)) (expt 10 d))) (expt 10 d))
    (if (zerop d)
        (format nil "~D." int)
        (format nil "~D.~V,'0D" int d frac))))

(defun addendum-tie-p (x d)
  (let ((r (* (abs (rational x)) (expt 10 d))))
    (= (- r (floor r)) 1/2)))

(defun addendum-f-failures (floats places)
  (let ((bad '()))
    (dolist (x floats (nreverse bad))
      (dolist (d places)
        (unless (addendum-tie-p x d)
          (let ((got (string-left-trim "-+" (format nil "~,vF" d x)))
                (want (addendum-exact-f x d)))
            ;; a leading zero is optional when the value is less than one
            (unless (or (string= got want)
                        (and (string= (subseq want 0 2) "0.")
                             (string= got (subseq want 1))))
              (push (list x d got want) bad))))))))

(deftest addendum.format.f-rounds-the-value.examples
  (addendum-f-failures '(2.675d0 1.005d0 0.125d0 1.0000001d0 0.07d0 2.5d0 1.45d0
                         0.1 2.675 1.005 9.995 64.79735)
                       '(0 1 2 3))
  nil)

(deftest addendum.format.f-rounds-the-value.generated
  (let* ((rnd (addendum-lcg 4242))
         (floats (loop repeat 400
                       for mantissa = (1+ (funcall rnd 1000000))
                       for scale = (expt 10 (- (funcall rnd 9) 4))
                       collect (float (* mantissa scale 1/1000) 1d0)
                       collect (float (* mantissa scale 1/1000) 1f0)))
         (failures (addendum-f-failures floats '(1 2 3 4))))
    (list (length failures) (first failures)))
  (0 nil))
