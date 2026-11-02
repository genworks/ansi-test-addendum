# ansi-test-addendum

Tests for Common Lisp behavior that the [ANSI-TEST](https://gitlab.common-lisp.net/ansi-test/ansi-test)
suite leaves open: cases where an implementation can pass every ANSI-TEST
test and still get the standard wrong.  They are written for ANSI-TEST's own
harness (RT, the `CL-TEST` package) and run beside it, but they are a
separate suite, not proposed for inclusion in ANSI-TEST.

## What goes in

A test belongs here when ANSI-TEST checks a fixed example and the bug
lives in the next case over: a value one past the example, a variable
where the example has a constant, a rank or adjustability the example
does not try, a pair of types its tables do not list.  So the tests
favor properties over expected outputs: SUBTYPEP checked against the
objects that inhabit each type, `*PRINT-READABLY*` checked by reading
the output back, generated forms from a fixed-seed generator so every
implementation sees the same ones.

Each test carries a comment giving the passage of the standard it rests
on, quoted, with a link to that passage on [metaspec.dev](https://metaspec.dev/),
and a line on why ANSI-TEST does not already catch it.

A test counts only once SBCL and CCL have been run on it: a failure there
is either shown to be that implementation's own bug or the test is
dropped or moved to `contested/`.  `contested/` holds readings of the
standard that both reference implementations decline; those tests load
only on request.

## Running

```sh
./run.sh sbcl
./run.sh ccl
./run.sh abcl:/path/to/abcl.jar
```

`run.sh` runs the implementation in a container (`clfoundation/sbcl`,
`clfoundation/ccl`, or a JDK image for ABCL) against a scratch copy of an
ANSI-TEST checkout (`ANSI_TEST`, default `../../github/ansi-test` from
this directory).  `COMPILE=1` compiles each test before running it;
`CONTESTED=1` adds the tests under `contested/`.

By hand, from an ANSI-TEST checkout:

```lisp
(load "gclload1.lsp")                  ; RT and CL-TEST, not ANSI-TEST's tests
(load "/path/to/ansi-test-addendum/load.lsp")
(rt:do-tests)
```

## Results, 2026-11-02

32 tests; the same results evaluated and compiled except where noted.

| implementation | failures |
|---|---|
| SBCL 2.6.10 | 0 |
| CCL 1.14 | 3 |
| ABCL 1.9.3-clnet.4 | 4 |
| ABCL master (2026-11-01) | 18 (17 compiled) |

CCL's three are its own bugs:

- `ADDENDUM.PRINT-READABLY.PRETTY-FORMS-READ-BACK`: a LOOP form with a
  dotted tail prints as `(LOOP ON NIL (NIL NIL . T) 3.5. 3.5)`, with no
  space before the dot, and reads back differently.
- `ADDENDUM.SCALE-FLOAT.RANGE-EDGES`: `(scale-float least-positive-double-float 1074)`
  returns `-0.0d0` (and the single-float case `0.0`) instead of `1.0`.
- `ADDENDUM.TYPE-OF.SUBTYPEP-CLASS-OF`: `(subtypep (type-of 0) (class-of 0))`
  returns one value, `T`, where SUBTYPEP returns two.

ABCL 1.9.3-clnet.4's four:

- `ADDENDUM.ARRAY-ELEMENT-TYPE.UPGRADED-FOR-EVERY-SHAPE`: an adjustable,
  fill-pointered or displaced `(unsigned-byte 16)` vector reports element
  type `T`.
- `ADDENDUM.DEFPACKAGE.REPEATED-NICKNAMES`: only the last `:NICKNAMES`
  clause is kept.
- `ADDENDUM.PRINT-READABLY.PATHNAMES`: a pathname with only a type prints
  as `#P".txt"`, and one named `"a.b"` as `#P"a.b"`; both read back with
  different name and type.
- `ADDENDUM.SUBTYPEP.SOUND`: `(subtypep 'simple-array (find-class 'simple-array))`
  is surely true, but a rank-zero simple array is not of the class.

## Layout

- `load.lsp` loads the tests after ANSI-TEST's `gclload1.lsp`.
- `tests/` the suite, one file per area of the standard; `tests/aux.lsp`
  holds the shared helpers (the fixed-seed generator, the float edges).
- `contested/` tests of a reading the reference implementations decline.
- `run.sh` the container runner.
