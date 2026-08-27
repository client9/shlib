. ./is_command.sh
. ./echoerr.sh
. ./log.sh
. ./http_download.sh
. ./mktmpdir.sh
. ./assert.sh

# test normal 200
test1() {
  http_download /dev/null https://raw.githubusercontent.com/client9/shlib/master/README.md
  assertEquals "$?" "0" "return != 0 on valid URL"
}

# test 404, missing
test2() {
  http_download /dev/null https://raw.githubusercontent.com/client9/shlib/master/does_not_exist
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
  before=$(find "$d" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')
  # subshell + plain assignment: a prefix assignment on a function call is
  # not portably visible inside the function
  (
    TMPDIR="$d"
    http_copy https://raw.githubusercontent.com/client9/shlib/master/does_not_exist
  ) >/dev/null 2>&1
  after=$(find "$d" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')
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
