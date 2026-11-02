;-*- Mode: Lisp -*-
;;;; Helpers shared by the addendum's tests.

(in-package :cl-test)

(defun addendum-lcg (seed)
  "A deterministic generator: (funcall g N) returns an integer in [0,N).
The same SEED gives every implementation the same sequence."
  (lambda (n)
    (setf seed (mod (+ (* seed 1103515245) 12345) 2147483648))
    (mod (floor seed 65536) n)))

(defun addendum-ieee-denormals-p ()
  "True where single and double floats are IEEE 754 binary32 and binary64
with denormals, so the float tests below can name exact values."
  (and (= (rational least-positive-double-float) (expt 2 -1074))
       (= (rational least-positive-single-float) (expt 2 -149))
       (= (float-digits 1d0) 53)
       (= (float-digits 1f0) 24)))

(defun addendum-denormals ()
  "Denormalized floats of both formats and both signs: K times the least
positive float, for K of every bit length the format's fraction holds."
  (when (addendum-ieee-denormals-p)
    (loop for (least bits) in (list (list least-positive-double-float 52)
                                    (list least-positive-single-float 23))
          nconc (loop for len from 1 to bits
                      for all-ones = (1- (ash 1 len))
                      for one-bit = (ash 1 (1- len))
                      nconc (loop for k in (list all-ones one-bit)
                                  for x = (* k least)
                                  collect x collect (- x))))))

(defun addendum-type-equal (a b)
  "True when SUBTYPEP is sure that A and B are the same type."
  (and (subtypep a b) (subtypep b a)))
