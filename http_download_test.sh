. ./is_command.sh
. ./echoerr.sh
. ./log.sh
. ./http_download.sh
. ./mktmpdir.sh
. ./assert.sh

# Every test here needs to actually fetch something.  Skip rather than fail on
# a machine with no downloader at all -- that is a real state (a stripped
# container), and distinct from FreeBSD, which has fetch but neither curl nor
# wget.
if ! is_command curl && ! is_command wget && ! is_command fetch; then
  assert_skip "no downloader available (curl, wget or fetch)"
  exit 0
fi

# count_entries DIR -- number of entries in DIR
#
# `ls -A` is POSIX and works everywhere. The alternatives do not:
#   find -mindepth   a GNU extension; Solaris find rejects it
#   for f in DIR/*   zsh treats an unmatched glob as an error (NOMATCH),
#                    where POSIX shells pass the pattern through
#
# SC2012 warns about parsing ls output, but this only counts lines, so odd
# filenames cannot mislead it.
# shellcheck disable=SC2012
count_entries() {
  ls -A "$1" 2>/dev/null | wc -l | tr -d ' '
}

# test normal 200
test1() {
  http_download /dev/null https://raw.githubusercontent.com/client9/shlib/master/README.md
  assertEquals "$?" "0" "return != 0 on valid URL"
}

# test 404, missing
test2() {
  # curl's own 404 message is expected here; keep it out of a passing run
  http_download /dev/null https://raw.githubusercontent.com/client9/shlib/master/does_not_exist 2>/dev/null
  assertNotEquals "$?" "0" "expected return to be non-zero on 404"
}

# --- http_copy ------------------------------------------------------------

# body reaches stdout intact
test3() {
  got=$(http_copy https://raw.githubusercontent.com/client9/shlib/master/fixtures/sample1.txt)
  assertEquals "foobar" "$got" "test3: http_copy returns the body"
}

# a failed fetch must report failure, not an empty success
test4() {
  http_copy https://raw.githubusercontent.com/client9/shlib/master/does_not_exist >/dev/null 2>&1
  assertNotEquals "0" "$?" "test4: http_copy fails on 404"
}

# the old version returned before removing its temp file on the error path
test5() {
  d=$(mktmpdir)
  before=$(count_entries "$d")
  # subshell + plain assignment: a prefix assignment on a function call is
  # not portably visible inside the function
  (
    TMPDIR="$d"
    http_copy https://raw.githubusercontent.com/client9/shlib/master/does_not_exist
  ) >/dev/null 2>&1
  after=$(count_entries "$d")
  assertEquals "$before" "$after" "test5: no temp file left behind after a failed fetch"
  rm -rf "$d"
}

# command substitution strips trailing newlines, so http_copy must not
# round-trip the body through a variable internally
test6() {
  n=$(http_copy https://raw.githubusercontent.com/client9/shlib/master/fixtures/sample1.txt | wc -c | tr -d ' ')
  assertEquals "7" "$n" "test6: trailing newline preserved (6 bytes + LF)"
}

test1
test2
test3
test4
test5
test6
