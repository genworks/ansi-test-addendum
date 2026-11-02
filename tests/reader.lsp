;-*- Mode: Lisp -*-
;;;; Reader: escapes in an uninterned symbol's name.

(in-package :cl-test)

;;; ------------------------------------------------------------------
;;; #: with escaped package markers.
;;;
;;; Spec: 2.4.8.5 Sharpsign Colon -- "#: introduces an uninterned
;;;   symbol whose name is symbol-name."
;;;   https://metaspec.dev/chap-2.html#sec_2_4_8_5
;;; and 2.1.4.6 Single Escape Character -- "A single escape is used to
;;;   indicate that the next character is to be treated as an
;;;   alphabetic character with its case preserved, no matter what the
;;;   character is or which constituent traits it has"; 2.1.4.5 says
;;;   the same of characters between multiple escapes.
;;;   https://metaspec.dev/chap-2.html#sec_2_1_4_6
;;; An escaped colon is part of the name, not a package marker.  A
;;; reader that rejects every colon after #: rejects these too.

(deftest addendum.sharpsign-colon.escaped-package-marker
  (loop for (text want) in '(("#:a\\:b" "A:B") ("#:|a:b|" "a:b") ("#:a|:|b" "A:B")
                             ("#:\\:" ":") ("#:|:|" ":"))
        for sym = (let ((*readtable* (copy-readtable nil)))
                    (read-from-string text))
        unless (and (symbolp sym) (null (symbol-package sym))
                    (string= (symbol-name sym) want))
          collect (list text sym))
  nil)
