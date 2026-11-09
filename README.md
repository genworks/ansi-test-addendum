# ansi-test-addendum

Tests for Common Lisp behavior that the [ANSI-TEST](https://gitlab.common-lisp.net/ansi-test/ansi-test)
suite leaves open: cases where an implementation can pass every ANSI-TEST
test and still get the standard wrong.  They are written for ANSI-TEST's own
harness (RT, the `CL-TEST` package) and run beside it, but they are a
separate suite, not proposed for inclusion in ANSI-TEST.

Written by [Genworks International](https://genworks.com).  MIT licensed,
like ANSI-TEST itself: copy the tests, adapt them, ship them with an
implementation or a distribution; keep the copyright notice.

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
standard that the reference implementations do not share, or that the
standard's own latitude leaves arguable; those tests load only on
request.

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

## Results

42 tests since 2026-11-05, 37 before; the same results evaluated and
compiled except where noted.

| implementation | date | tests | failures |
|---|---|---|---|
| SBCL 2.6.10 | 2026-11-09 | 42 | 0 |
| CCL 1.14 | 2026-11-09 | 42 | 3 |
| miricl 6af4d0eb, precompiled image, Node 26 | 2026-11-09 | 42 | 0 |
| ABCL 1.9.3, stock, evaluated only | 2026-11-05 | 42 | 24 |
| ABCL 1.9.3-clnet.5 | 2026-11-02 | 37 | 3 |
| ABCL master (2026-11-01) | 2026-11-02 | 37 | 23 (22 compiled) |

The five tests added 2026-11-05, on the values of backquote templates,
are the portable part of fare-quasiquote's test suite, by its author's
suggestion.  Stock ABCL fails one of them, `ADDENDUM.BACKQUOTE.VECTORS`:
`` `#.#(1 2 3) `` signals an error, as it does on CMUCL.  The sixth,
under `contested/`, is `ADDENDUM.BACKQUOTE.SPLICE-SEVERAL-FORMS`: SBCL
passes it and CCL fails it, and its comment says why that is arguable.

miricl (Common Lisp on WebAssembly, run under Node) found a fault in the
addendum itself on 2026-11-09.  Three tests called `FIND-CLASS` on
`SIMPLE-ARRAY`, `SIMPLE-VECTOR`, `SIMPLE-STRING`, `SIMPLE-BIT-VECTOR`,
`BASE-STRING` and `SIMPLE-BASE-STRING`, which Figure 4-8 does not make
classes, and miricl, having no classes of those names, signaled an
error.  They now check those names only where the implementation has
such a class.  With that, miricl passes all 42, evaluated and compiled,
and the three under `contested/` as well.

CCL's three are its own bugs:

- `ADDENDUM.PRINT-READABLY.PRETTY-FORMS-READ-BACK`: a LOOP form with a
  dotted tail prints as `(LOOP ON NIL (NIL NIL . T) 3.5. 3.5)`, with no
  space before the dot, and reads back differently.
- `ADDENDUM.SCALE-FLOAT.RANGE-EDGES`: `(scale-float least-positive-double-float 1074)`
  returns `-0.0d0` (and the single-float case `0.0`) instead of `1.0`.
- `ADDENDUM.TYPE-OF.SUBTYPEP-CLASS-OF`: `(subtypep (type-of 0) (class-of 0))`
  returns one value, `T`, where SUBTYPEP returns two.

ABCL 1.9.3-clnet.5's three:

- `ADDENDUM.DEFPACKAGE.REPEATED-NICKNAMES`: only the last `:NICKNAMES`
  clause is kept.
- `ADDENDUM.PRINT-READABLY.PATHNAMES`: a pathname with only a type prints
  as `#P".txt"`, and one named `"a.b"` as `#P"a.b"`; both read back with
  different name and type.
- `ADDENDUM.PRINT-READABLY.PATHNAMES-MORE`: a pathname whose directory is
  `(:relative :back)` prints as `#P"/z"`, which reads back absolute.

1.9.3-clnet.4 also failed `ADDENDUM.ARRAY-ELEMENT-TYPE.UPGRADED-FOR-EVERY-SHAPE`
(an adjustable, fill-pointered or displaced `(unsigned-byte 16)` vector
reported element type `T`) and `ADDENDUM.SUBTYPEP.SOUND` (a rank-zero
simple array was not of the class `SIMPLE-ARRAY`).  The tests added
2026-11-02 found more in ABCL master, all passing on clnet.5: arrays of
`(unsigned-byte 8)` and 16 that keep 256 or 65536 as another number,
`SUBSEQ`, `REVERSE` and `ADJUST-ARRAY` results of element type `T`, and
an `ADJUST-ARRAY` that ends the thread with a Java exception.

## Layout

- `load.lsp` loads the tests after ANSI-TEST's `gclload1.lsp`.
- `tests/` the suite, one file per area of the standard; `tests/aux.lsp`
  holds the shared helpers (the fixed-seed generator, the float edges,
  and `ADDENDUM-ISOLATED`, which on ABCL runs a case in a thread of its
  own so that a Java exception escaping a primitive ends that thread,
  not the run).
- `contested/` tests of a reading the reference implementations decline.
- `run.sh` the container runner.

## License

MIT; see `LICENSE`.  Copyright (c) 2026 Genworks International.
