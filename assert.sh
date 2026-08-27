#
# assert.sh: minimal test assertions for posix shell
#
# Assertions are NON-FATAL: a failure is recorded and the file keeps going,
# so one bad assertion does not hide every test after it.  Totals are printed
# by an EXIT trap, which also sets the exit status, so a test file cannot
# forget to report.
#
# Set ASSERT_VERBOSE=1 to also print passing assertions.
#
_assert_pass=0
_assert_fail=0
_assert_skip=0
_assert_file=${0##*/}

_assert_ok() {
  _assert_pass=$((_assert_pass + 1))
  test -z "$ASSERT_VERBOSE" || echo "ok   ${_assert_file}: $1"
}

_assert_no() {
  _assert_fail=$((_assert_fail + 1))
  echo "FAIL ${_assert_file}: $1" >&2
}

# assert_skip records a test that could not run (missing dependency).
# It is not a failure.
assert_skip() {
  _assert_skip=$((_assert_skip + 1))
  echo "skip ${_assert_file}: $1" >&2
}

assertTrue() {
  if eval "$1"; then
    _assert_ok "$2"
  else
    _assert_no "assertTrue [$1] $2"
  fi
}

assertFalse() {
  if eval "$1"; then
    _assert_no "assertFalse [$1] $2"
  else
    _assert_ok "$2"
  fi
}

assertEquals() {
  if [ "$1" = "$2" ]; then
    _assert_ok "$3"
  else
    _assert_no "assertEquals want='$1' got='$2' $3"
  fi
}

assertNotEquals() {
  if [ "$1" != "$2" ]; then
    _assert_ok "$3"
  else
    _assert_no "assertNotEquals want!='$1' got='$2' $3"
  fi
}

# assert_summary prints totals and exits with the right status.  It is wired
# to EXIT below; calling it directly is harmless but unnecessary.
assert_summary() {
  test -z "$_assert_done" || return 0
  _assert_done=1
  _assert_total=$((_assert_pass + _assert_fail))
  if [ "$_assert_fail" -gt 0 ]; then
    echo "FAIL ${_assert_file}: ${_assert_fail}/${_assert_total} assertions failed" >&2
    exit 1
  fi
  if [ "$_assert_skip" -gt 0 ]; then
    echo "ok   ${_assert_file}: ${_assert_total} assertions, ${_assert_skip} skipped"
    exit 0
  fi
  echo "ok   ${_assert_file}: ${_assert_total} assertions"
  exit 0
}

trap assert_summary EXIT
