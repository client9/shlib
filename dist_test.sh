. ./assert.sh

# The released artifact is what downstream projects actually embed, so test it
# directly rather than only testing the individual source files.  Being a
# *_test.sh, this runs across the whole shell matrix automatically.
if [ ! -f ./dist/shlib.min.sh ]; then
  assert_skip "dist/shlib.min.sh not built - run 'make dist'"
  # the EXIT trap in assert.sh still prints the summary
  exit 0
fi

# generated file; shellcheck cannot usefully follow it
# shellcheck source=/dev/null
. ./dist/shlib.min.sh

test_version_marker() {
  # the marker must survive comment stripping; it is what makes a stale
  # vendored copy identifiable in a bug report
  got=$(grep -c '^shlib [0-9][0-9][0-9][0-9]\.[0-9][0-9]\.[0-9][0-9]' ./dist/shlib.min.sh)
  assertEquals "1" "$got" "version marker present in stripped bundle"
}

test_uname() {
  assertNotEquals "" "$(uname_os)" "uname_os returns a value"
  assertNotEquals "" "$(uname_arch)" "uname_arch returns a value"
  assertTrue "uname_os_check" "uname_os_check passes"
  assertTrue "uname_arch_check" "uname_arch_check passes"
}

test_hash() {
  want="aec070645fe53ee3b3763059376134f058cc337247c978add178b6ccdfb0019f"
  assertEquals "$want" "$(echo foobar | hash_sha256)" "hash_sha256 from bundle"
  assertEquals "14758f1afd44c09b7992073ccf00b43d" "$(echo foobar | hash_md5)" "hash_md5 from bundle"
}

test_mktmpdir() {
  d=$(mktmpdir)
  assertTrue "[ -d '$d' ]" "mktmpdir from bundle"
  rmdir "$d" 2>/dev/null
}

test_untar() {
  assertFalse "untar some-file.rar" "untar rejects unknown format (log_err is wired up)"
}

test_version_marker
test_uname
test_hash
test_mktmpdir
test_untar
