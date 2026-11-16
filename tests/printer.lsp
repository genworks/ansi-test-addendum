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

;;; Each pathname is made inside a handler: 19.2.2.1.1 leaves it
;;; implementation-defined whether a separator character may appear
;;; inside a component, and 19.2.2.5 gives implementation-dependent
;;; limits on the component strings and the directory list, so an
;;; implementation may refuse to make one of these, and that case is
;;; skipped.  https://metaspec.dev/chap-19.html#sec_19_2_2_5
;;; A PRINT-NOT-READABLE on printing skips the case too, since that is
;;; the conforming way to decline.  So that neither way can pass the
;;; test with nothing exercised, each test also returns whether at
;;; least one of its cases printed and was read back.
(defun addendum-pathname-readback (args)
  "Make the pathname ARGS describe, print it readably and read it back:
:SKIPPED when the implementation refuses to make it or signals
PRINT-NOT-READABLE, :OK when the components read back, else a list
describing the failure."
  (let ((p (handler-case (apply #'make-pathname args)
             (error () nil))))
    (if (null p)
        :skipped
        (let ((text (handler-case (let ((*print-readably* t)) (prin1-to-string p))
                      (print-not-readable () nil))))
          (cond ((null text) :skipped)
                ((let ((back (handler-case (read-from-string text)
                               (error (e) (list :read-error (type-of e))))))
                   (and (pathnamep back)
                        (equal (addendum-pathname-components back)
                               (addendum-pathname-components p))))
                 :ok)
                (t (list args text)))))))

(defun addendum-pathname-readback-failures (cases)
  "The failures among CASES, each a MAKE-PATHNAME argument list, and
whether any case was exercised."
  (let ((bad '()) (exercised nil))
    (dolist (args cases (list (nreverse bad) exercised))
      (let ((r (addendum-pathname-readback args)))
        (case r
          (:skipped)
          (:ok (setf exercised t))
          (t (setf exercised t) (push r bad)))))))

(deftest addendum.print-readably.pathnames
  (addendum-pathname-readback-failures
   '((:type "txt") (:name "a.b") (:name ".emacs")
     (:name "a" :type "b" :version :newest)
     (:directory (:absolute "tmp")) (:directory (:relative "x" "y") :name "z")))
  (nil t))

;;; More pathnames printed readably: dots inside names and types, wild
;;; components, :UP and :BACK.  ANSI-TEST's readability test
;;; (PRINT.PATHNAME.1) prints the pathnames of its *UNIVERSE*, sixteen of
;;; them, none with a dot inside a name or type and none with :UP or
;;; :BACK in the directory.

(deftest addendum.print-readably.pathnames-more
  (addendum-pathname-readback-failures
   '((:name ".emacs" :type "el") (:name "a.b" :type "c")
     (:name "a" :type "b.c") (:name :wild :type "lisp")
     (:name "a" :type :wild)
     (:directory (:relative :up) :name "z")
     (:directory (:relative :back) :name "z")
     (:directory (:absolute :wild-inferiors) :name "z")
     (:directory (:absolute "a.b") :name "c")
     (:name "a*b") (:name "a\\b") (:name "a\"b")))
  (nil t))
