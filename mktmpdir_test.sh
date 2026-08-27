. ./assert.sh
. ./is_command.sh
. ./echoerr.sh
. ./log.sh
. ./mktmpdir.sh

# each call must return a NEW, private directory.  The old implementation
# returned $TMPDIR verbatim when it was set, so two calls collided and the
# directory was shared with every other process on the box.
test1() {
  a=$(mktmpdir)
  b=$(mktmpdir)
  assertNotEquals "$a" "$b" "test1: two calls must return different directories"
  rmdir "$a" "$b" 2>/dev/null
}

test2() {
  d=$(mktmpdir)
  assertTrue "[ -d '$d' ]" "test2: returned path is a directory"
  rmdir "$d" 2>/dev/null
}

test3() {
  d=$(mktmpdir)
  got=$(find "$d" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')
  assertEquals "0" "$got" "test3: new directory is empty"
  rmdir "$d" 2>/dev/null
}

# TMPDIR is the PARENT, not the result
test4() {
  parent=$(mktmpdir)
  d=$(TMPDIR="$parent" mktmpdir)
  assertNotEquals "$parent" "$d" "test4: result must not be TMPDIR itself"
  case "$d" in
    "$parent"/*) assertTrue "true" "test4b: result is created inside TMPDIR" ;;
    *) assertTrue "false" "test4b: result '$d' is not inside TMPDIR '$parent'" ;;
  esac
  rmdir "$d" "$parent" 2>/dev/null
}

# must not clobber the caller's TMPDIR as a side effect
test5() {
  TMPDIR_before=$TMPDIR
  d=$(mktmpdir)
  assertEquals "$TMPDIR_before" "$TMPDIR" "test5: caller's TMPDIR must be unchanged"
  rmdir "$d" 2>/dev/null
}

# private to the owner (mktemp -d creates 0700)
test6() {
  d=$(mktmpdir)
  # ls -ld is the portable way to read a mode; the path is one we just
  # created, so the SC2012 filename concerns do not apply
  # shellcheck disable=SC2012
  mode=$(ls -ld "$d" | cut -c1-10)
  assertEquals "drwx------" "$mode" "test6: directory is private (0700)"
  rmdir "$d" 2>/dev/null
}

test1
test2
test3
test4
test5
test6
