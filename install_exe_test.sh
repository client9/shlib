# shellcheck disable=SC1091
. ./assert.sh
. ./is_command.sh
. ./echoerr.sh
. ./log.sh
. ./mktmpdir.sh
. ./install_exe.sh

test_copies_and_makes_executable() {
  d=$(mktmpdir)
  echo '#!/bin/sh' >"$d/src"
  assertTrue "install_exe '$d/src' '$d/dst'" "install_exe: succeeds"
  assertTrue "[ -x '$d/dst' ]" "install_exe: destination is executable"
  assertEquals "$(cat "$d/src")" "$(cat "$d/dst")" "install_exe: contents copied"
  rm -rf "$d"
}

# the source may be non-executable; the destination must still end up 0755
test_sets_mode_regardless_of_source() {
  d=$(mktmpdir)
  echo 'x' >"$d/src"
  chmod 0600 "$d/src"
  install_exe "$d/src" "$d/dst" >/dev/null 2>&1
  # ls -l is the portable way to read a mode; these paths are ones we just
  # created, so the SC2012 filename concerns do not apply
  # shellcheck disable=SC2012
  mode=$(ls -l "$d/dst" | cut -c1-10)
  assertEquals "-rwxr-xr-x" "$mode" "install_exe: destination is 0755 even from a 0600 source"
  rm -rf "$d"
}

# overwriting a running binary fails with ETXTBSY on some systems, so the
# destination is unlinked first
test_overwrites_existing() {
  d=$(mktmpdir)
  printf 'old\n' >"$d/src"
  install_exe "$d/src" "$d/dst" >/dev/null 2>&1
  # A hard link to the destination distinguishes the two implementations:
  # if install_exe unlinks first, the link keeps the OLD contents; if it
  # truncates in place, the link would show the new ones.  That is the actual
  # consequence of unlinking, and unlike inode identity it is portable --
  # Linux happily reuses a just-freed inode number, so comparing inodes
  # reported "not unlinked" on ext4 while passing on APFS.
  ln "$d/dst" "$d/hardlink"

  printf 'new\n' >"$d/src"
  assertTrue "install_exe '$d/src' '$d/dst'" "install_exe: overwrites an existing destination"
  assertEquals "new" "$(cat "$d/dst")" "install_exe: destination has the new contents"
  assertEquals "old" "$(cat "$d/hardlink")" "install_exe: destination is unlinked, not truncated in place"
  rm -rf "$d"
}

# replacing a binary while a copy of it is executing
test_overwrites_while_running() {
  d=$(mktmpdir)
  printf '#!/bin/sh\nsleep 2\n' >"$d/src"
  install_exe "$d/src" "$d/dst" >/dev/null 2>&1
  "$d/dst" &
  _pid=$!
  printf '#!/bin/sh\necho replaced\n' >"$d/src"
  assertTrue "install_exe '$d/src' '$d/dst'" "install_exe: replaces a binary that is executing"
  kill "$_pid" 2>/dev/null
  wait "$_pid" 2>/dev/null
  rm -rf "$d"
}

test_missing_source_fails() {
  d=$(mktmpdir)
  assertFalse "install_exe '$d/nope' '$d/dst' 2>/dev/null" "install_exe: missing source fails"
  assertFalse "[ -e '$d/dst' ]" "install_exe: nothing created when the source is missing"

  # cp would fail on its own; the point of the explicit check is a message
  # that names the function and the file
  msg=$(install_exe "$d/nope" "$d/dst" 2>&1 >/dev/null)
  case "$msg" in
    *install_exe*"$d/nope"*) assertTrue "true" "install_exe: names the function and the missing source" ;;
    *) assertTrue "false" "install_exe: unhelpful message [$msg]" ;;
  esac
  rm -rf "$d"
}

test_bad_args_fail() {
  assertFalse "install_exe" "install_exe: no arguments fails"
  d=$(mktmpdir)
  echo x >"$d/src"
  assertFalse "install_exe '$d/src'" "install_exe: a missing destination fails"
  rm -rf "$d"
}

test_unwritable_destination_fails() {
  d=$(mktmpdir)
  echo x >"$d/src"
  mkdir "$d/ro"
  chmod 0500 "$d/ro"
  # root ignores the permission bits, so only assert where it is meaningful
  if [ -w "$d/ro" ]; then
    assert_skip "install_exe: running as root, permission check is meaningless"
  else
    assertFalse "install_exe '$d/src' '$d/ro/dst'" "install_exe: unwritable destination fails"
  fi
  chmod 0700 "$d/ro"
  rm -rf "$d"
}

# install(1) must not be required: it is not POSIX and Solaris/illumos ship an
# incompatible SVR4 version
test_does_not_use_install_1() {
  d=$(mktmpdir)
  mkdir "$d/fakebin"
  printf '#!/bin/sh\necho "install: invalid usage" >&2\nexit 1\n' >"$d/fakebin/install"
  chmod 0755 "$d/fakebin/install"
  echo '#!/bin/sh' >"$d/src"
  got=$(PATH="$d/fakebin:$PATH" sh -c ". ./echoerr.sh; . ./log.sh; . ./install_exe.sh
    install_exe '$d/src' '$d/dst' >/dev/null 2>&1; echo \$?")
  assertEquals "0" "$got" "install_exe: works with a broken SVR4-style install(1) on PATH"
  rm -rf "$d"
}

test_copies_and_makes_executable
test_sets_mode_regardless_of_source
test_overwrites_existing
test_overwrites_while_running
test_missing_source_fails
test_bad_args_fail
test_unwritable_destination_fails
test_does_not_use_install_1
