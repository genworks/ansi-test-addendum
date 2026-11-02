;-*- Mode: Lisp -*-
;;;; Printer: what *PRINT-READABLY* promises, checked by reading the
;;;; output back.

(in-package :cl-test)

;;; ------------------------------------------------------------------
;;; A form printed readably and pretty reads back EQUAL.
;;;
;;; Spec: *PRINT-READABLY* -- "printing any object O1 produces a printed
;;;   representation that, when seen by the Lisp reader while the
;;;   standard readtable is in effect, will produce an object O2 that is
;;;   similar to O1. ... If printing an object readably is not possible,
;;;   an error of type print-not-readable is signaled."
;;;   https://metaspec.dev/v_stprint-readablyst.html
;;; The pretty printer's special forms (LOOP, LET, DEFUN, ...) lay
;;; their arguments out by position; a malformed or dotted form must
;;; still print in full.  ANSI-TEST prints such forms only with fixed
;;; examples; these are generated, the same for every implementation.

(defparameter *addendum-pprint-heads*
  '(loop let let* flet labels macrolet symbol-macrolet cond case ecase typecase
    do do* dolist dotimes defun defmacro lambda block return-from if when unless
    progn prog1 tagbody prog function quote setq psetq multiple-value-bind
    destructuring-bind handler-case unwind-protect catch defvar defparameter
    defstruct defclass defmethod declare the locally eval-when))

(defparameter *addendum-loop-words*
  '(for in on from to by below above downto across being the each of using
    with = then and do collect append nconc sum count maximize minimize
    when if unless else end return initially finally repeat while until
    always never thereis named into of-type))

(defparameter *addendum-pprint-atoms* '(nil t x y z a b 1 -2 3.5 "s" #\c :k))

(defun addendum-random-form (rnd head)
  (labels ((pick (list) (nth (funcall rnd (length list)) list))
           (atom* () (if (and (eq head 'loop) (< (funcall rnd 10) 6))
                         (pick *addendum-loop-words*)
                         (pick *addendum-pprint-atoms*)))
           (dot (items) (let ((l (copy-list items))) (setf (cdr (last l)) (atom*)) l))
           (element (depth)
             (case (funcall rnd (if (> depth 2) 3 5))
               ((0 1 2) (atom*))
               (3 (sublist (1+ depth)))
               (t (cons (atom*) (sublist (1+ depth))))))
           (sublist (depth)
             (let ((items (loop repeat (funcall rnd 5) collect (element depth))))
               (if (and items (= 0 (funcall rnd 6))) (dot items) items))))
    (let ((body (loop repeat (funcall rnd 7) collect (element 1))))
      (if (and body (= 0 (funcall rnd 8)))
          (dot (cons head body))
          (cons head body)))))

(defun addendum-readback-failures (forms margins)
  (let ((bad '()))
    (dolist (form forms (nreverse bad))
      (dolist (margin margins)
        (let ((text (handler-case
                        (let ((*print-pretty* t) (*print-readably* t)
                              (*print-right-margin* margin) (*package* (find-package :cl-test)))
                          (prin1-to-string form))
                      (print-not-readable () :not-readable)
                      (error (e) (list :print-error (type-of e))))))
          (cond ((eq text :not-readable))
                ((not (stringp text)) (push (list form margin text) bad))
                (t (let ((back (handler-case
                                   (let ((*package* (find-package :cl-test)))
                                     (read-from-string text))
                                 (error (e) (list :read-error (type-of e))))))
                     (unless (equal back form) (push (list form margin text) bad))))))))))

(deftest addendum.print-readably.pretty-forms-read-back
  (let ((rnd (addendum-lcg 12345)))
    (let ((failures (addendum-readback-failures
                     (loop for head in *addendum-pprint-heads*
                           nconc (loop repeat 100 collect (addendum-random-form rnd head)))
                     '(200 30))))
      (subseq failures 0 (min 5 (length failures)))))
  nil)

;;; Circular structure under *PRINT-CIRCLE*, pretty and not, reads back
;;; with the same sharing.
;;;
;;; Spec: *PRINT-CIRCLE* -- "If true, the printer will endeavor to
;;;   detect cycles and sharing in the structure to be printed, and to
;;;   use #n= and #n# syntax to indicate the circularities or shared
;;;   components."  https://metaspec.dev/v_stprint-circlest.html

(deftest addendum.print-circle.reads-back
  (let ((results '()))
    (dolist (pretty '(nil t) (nreverse results))
      (let* ((cycle (list 1 2)) (shared (list :s))
             (structure (list cycle shared shared)))
        (setf (cddr cycle) cycle)
        (let* ((text (let ((*print-circle* t) (*print-pretty* pretty) (*print-readably* nil))
                       (prin1-to-string structure)))
               (back (read-from-string text)))
          (push (and (eql (first (first back)) 1)
                     (eq (cddr (first back)) (first back))
                     (eq (second back) (third back)))
                results)))))
  (t t))

;;; ------------------------------------------------------------------
;;; Pathnames printed readably read back with the same components.
;;;
;;; Spec: *PRINT-READABLY* as above, and 3.2.4.2.2 Definition of
;;;   Similarity
;;;   Similarity for pathnames: "Two pathnames S and C are similar if
;;;   all corresponding pathname components are similar."
;;;   https://metaspec.dev/chap-3.html#sec_3_2_4_2_2

;;; The version is left out: SBCL prints a pathname whose version is
;;; NIL as a namestring that parses back with version :NEWEST, and
;;; whether that pair is similar is arguable.  The other components
;;; are not.
(defun addendum-pathname-components (p)
  (list (pathname-host p) (pathname-device p) (pathname-directory p)
        (pathname-name p) (pathname-type p)))

(deftest addendum.print-readably.pathnames
  (loop for p in (list (make-pathname :type "txt")
                       (make-pathname :name "a.b")
                       (make-pathname :name ".emacs")
                       (make-pathname :name "a" :type "b" :version :newest)
                       (make-pathname :directory '(:absolute "tmp"))
                       (make-pathname :directory '(:relative "x" "y") :name "z"))
        for text = (handler-case (let ((*print-readably* t)) (prin1-to-string p))
                     (print-not-readable () nil))
        unless (or (null text)
                   (let ((back (read-from-string text)))
                     (and (pathnamep back)
                          (equal (addendum-pathname-components back)
                                 (addendum-pathname-components p)))))
          collect (list (addendum-pathname-components p) text))
  nil)
