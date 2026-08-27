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

# The minifier must not change behaviour.  It once did: the old
# `grep -v ' #'` filter deleted code lines that carried trailing comments,
# silently removing the win*->windows mapping and both gitrepo= assignments.
# Compare the bundle against the sources for every mapping case.
test_bundle_matches_sources() {
  for probe in Linux Darwin FreeBSD MINGW64_NT-10.0 MSYS_NT-10.0 CYGWIN_NT-10.0 Windows_NT AIX; do
    want=$(sh -c ". ./uname_os.sh
      uname() { case \"\$1\" in -s) echo '$probe' ;; -o) return 1 ;; esac; }
      uname_os")
    got=$(sh -c ". ./dist/shlib.min.sh
      uname() { case \"\$1\" in -s) echo '$probe' ;; -o) return 1 ;; esac; }
      uname_os")
    assertEquals "$want" "$got" "bundle matches sources for uname -s '$probe'"
  done

  for probe in x86_64 aarch64 armv7l loongarch64 riscv64; do
    want=$(sh -c ". ./uname_arch.sh; uname() { echo '$probe'; }; uname_arch")
    got=$(sh -c ". ./dist/shlib.min.sh; uname() { echo '$probe'; }; uname_arch")
    assertEquals "$want" "$got" "bundle matches sources for uname -m '$probe'"
  done
}

# every function defined in a source file must survive into the bundle
test_no_function_lost() {
  missing=""
  for f in ./*.sh; do
    case "$f" in ./*_test.sh | ./assert.sh) continue ;; esac
    for fn in $(grep -oE '^[a-z_][a-z0-9_]*\(\)' "$f" | tr -d '()'); do
      grep -q "^${fn}()" ./dist/shlib.min.sh || missing="$missing $fn"
    done
  done
  assertEquals "" "$missing" "no function lost in minification"
}

test_bundle_matches_sources
test_no_function_lost
