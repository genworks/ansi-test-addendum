#!/bin/sh
# run.sh IMPL [LOG] -- run the addendum on one implementation, in a
# container, against a scratch copy of an ANSI-TEST checkout.
#   IMPL: sbcl | ccl | abcl:/path/to/abcl.jar
#   ANSI_TEST: the ansi-test checkout (default ../../github/ansi-test
#              from this directory); COMPILE=1 compiles each test first.
# Prints ANSI-TEST's summary line and the names of the failing tests.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
ANSI_TEST=${ANSI_TEST:-$HERE/../../github/ansi-test}
LOG=${2:-$(mktemp)}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
# the committed tree only: a checkout can hold another Lisp's fasls
mkdir -p "$WORK/ansi-test"
git -C "$ANSI_TEST" archive HEAD | tar -x -C "$WORK/ansi-test"
if [ -n "$COMPILE" ]; then COMPILE_VALUE=t; else COMPILE_VALUE=nil; fi
COMPILE_FORM="(setf (symbol-value (find-symbol \"*COMPILE-TESTS*\" \"REGRESSION-TEST\")) $COMPILE_VALUE)"
RUN_FORM='(funcall (find-symbol "DO-TESTS" "REGRESSION-TEST"))'
if [ -n "$CONTESTED" ]; then CONTESTED_FORM='(defvar cl-user::*addendum-contested* t)'
else CONTESTED_FORM='(defvar cl-user::*addendum-contested* nil)'; fi
DOCKER="docker run --rm --memory=3g --user $(id -u):$(id -g) -e HOME=/tmp
  -v $WORK/ansi-test:/ansi-test -v $HERE:/addendum:ro -w /ansi-test"
case "$1" in
  sbcl)
    $DOCKER ${SBCL_IMAGE:-clfoundation/sbcl:2.6.10} sbcl --dynamic-space-size 2048 --non-interactive \
      --load gclload1.lsp --eval "$CONTESTED_FORM" --load /addendum/load.lsp --eval "$COMPILE_FORM" --eval "$RUN_FORM" > "$LOG" 2>&1 || true ;;
  ccl)
    $DOCKER ${CCL_IMAGE:-clfoundation/ccl:1.14-trixie-slim} ccl --batch --no-init \
      --load gclload1.lsp --eval "$CONTESTED_FORM" --load /addendum/load.lsp --eval "$COMPILE_FORM" --eval "$RUN_FORM" \
      --eval '(ccl:quit)' > "$LOG" 2>&1 < /dev/null || true ;;
  abcl:*)
    JAR=${1#abcl:}
    $DOCKER -v "$(dirname "$JAR")":/jar:ro ${ABCL_IMAGE:-abcl-build:21} \
      java -Xss16m -Xmx2g -jar /jar/$(basename "$JAR") --noinform --noinit --batch \
      --load gclload1.lsp --eval "$CONTESTED_FORM" --load /addendum/load.lsp --eval "$COMPILE_FORM" --eval "$RUN_FORM" \
      --eval '(ext:quit)' > "$LOG" 2>&1 || true ;;
  *) echo "usage: $0 sbcl|ccl|abcl:JAR [LOG]" >&2; exit 2 ;;
esac
grep -E 'out of [0-9]+ test|No tests failed' "$LOG" || { echo "no summary; log: $LOG"; tail -20 "$LOG"; }
grep -oE '^Test [^ ]+ failed' "$LOG" | sort -u || true
