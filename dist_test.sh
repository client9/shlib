. ./assert.sh

# The released artifact is what downstream projects actually embed, so test it
# directly rather than only testing the individual source files.  Being a
# *_test.sh, this runs across the whole shell matrix automatically.
if [ ! -f ./dist/shlib.sh ]; then
  assert_skip "dist/shlib.sh not built - run 'make dist'"
  # the EXIT trap in assert.sh still prints the summary
  exit 0
fi

# generated file; shellcheck cannot usefully follow it
# shellcheck source=/dev/null
. ./dist/shlib.sh

test_version_marker() {
  # what makes a stale vendored copy identifiable in a bug report.  It lives in
  # a heredoc rather than a comment so that `sed -n 's/^shlib \(.*\)/\1/p'`
  # keeps matching copies already in the wild.
  got=$(grep -c '^shlib [0-9][0-9][0-9][0-9]\.[0-9][0-9]\.[0-9][0-9]' ./dist/shlib.sh)
  assertEquals "1" "$got" "version marker present in the bundle"
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

# The bundle must behave exactly like the sources it was concatenated from.
#
# This existed to police the minifier, which once broke exactly this: the old
# `grep -v ' #'` filter deleted code lines carrying trailing comments and
# silently removed the win*->windows mapping and both gitrepo= assignments.
# Stripping is gone and `cat` is now the only transformation, but the check
# stays cheap and would still catch a botched file list or ordering.
test_bundle_matches_sources() {
  for probe in Linux Darwin FreeBSD MINGW64_NT-10.0 MSYS_NT-10.0 CYGWIN_NT-10.0 Windows_NT AIX; do
    want=$(sh -c ". ./uname_os.sh
      uname() { case \"\$1\" in -s) echo '$probe' ;; -o) return 1 ;; esac; }
      uname_os")
    got=$(sh -c ". ./dist/shlib.sh
      uname() { case \"\$1\" in -s) echo '$probe' ;; -o) return 1 ;; esac; }
      uname_os")
    assertEquals "$want" "$got" "bundle matches sources for uname -s '$probe'"
  done

  for probe in x86_64 aarch64 armv7l loongarch64 riscv64; do
    want=$(sh -c ". ./uname_arch.sh; uname() { echo '$probe'; }; uname_arch")
    got=$(sh -c ". ./dist/shlib.sh; uname() { echo '$probe'; }; uname_arch")
    assertEquals "$want" "$got" "bundle matches sources for uname -m '$probe'"
  done
}

# every function defined in a source file must survive into the bundle
test_no_function_lost() {
  # Deliberately avoids `case` inside $( ): bash 3.2 -- /bin/sh on macOS --
  # reads the pattern's closing ")" as the end of the command substitution and
  # fails to parse.  The balanced-paren form "(pattern)" fixes that, but shfmt
  # normalises it straight back out again.
  #
  # `while read` from a REDIRECT rather than a pipe, so the loop runs in this
  # shell and the accumulated variable survives.
  #
  # sed, not `grep -oE`: Solaris ships the SVR4 grep, which has neither.
  _tmpd=$(mktmpdir)
  for f in ./*.sh; do
    case "$f" in
      ./*_test.sh | ./assert.sh) continue ;;
    esac
    sed -n 's/^\([a-z_][a-z0-9_]*\)().*/\1/p' "$f" >>"$_tmpd/fns"
  done

  missing=""
  while read -r fn; do
    grep -q "^${fn}()" ./dist/shlib.sh || missing="$missing $fn"
  done <"$_tmpd/fns"
  rm -rf "$_tmpd"

  assertEquals "" "$missing" "no function lost in the bundle"
}

test_bundle_matches_sources
test_no_function_lost

# The library must not clobber the caller's variables.  It used to: calling
# github_release overwrote $version, and uname_os overwrote $os.  Everything
# internal is now prefixed _shlib_.
#
# Compare the variable set before and after rather than assuming the
# environment holds no lowercase names -- GitHub's Windows runners export
# npm_config_prefix, which an absolute check flagged as a leak.
test_no_variable_leak() {
  workdir=$(mktmpdir)
  sh -c '
    varnames() { set | sed -n "s/^\([a-z][A-Za-z0-9_]*\)=.*/\1/p" | sort; }
    varnames >"$1/before"
    . ./dist/shlib.sh
    echo foobar | hash_sha256 >/dev/null 2>&1
    uname_os >/dev/null 2>&1
    uname_arch >/dev/null 2>&1
    uname_os_check >/dev/null 2>&1
    uname_arch_check >/dev/null 2>&1
    hash_sha256_verify fixtures/sample1.txt fixtures/sha256-checksums.txt >/dev/null 2>&1
    untar x.rar >/dev/null 2>&1
    varnames >"$1/after"
  ' _ "$workdir"

  # Lines present in "after" but not "before".
  #
  # Not `grep -Fxv -f`: Solaris ships the SVR4 grep, which has none of -F, -x
  # or -f.  Listing "before" twice makes anything from it appear at least
  # twice, so `uniq -u` leaves only what is new -- using just sort and uniq,
  # which are everywhere.
  leaked=$(cat "$workdir/before" "$workdir/before" "$workdir/after" |
    sort | uniq -u | grep -v "^_shlib_" | tr "\n" " ")
  rm -rf "$workdir"
  assertEquals "" "$leaked" "library leaves no unprefixed lowercase globals behind"
}

# and the specific collision that started this
test_caller_variables_survive() {
  got=$(sh -c '. ./dist/shlib.sh
    version=mine; os=mine; arch=mine; want=mine; got=mine; url=mine; tarball=mine
    uname_os >/dev/null 2>&1; uname_arch >/dev/null 2>&1
    hash_sha256_verify fixtures/sample1.txt fixtures/sha256-checksums.txt >/dev/null 2>&1
    untar x.rar >/dev/null 2>&1
    echo "$version$os$arch$want$got$url$tarball"')
  assertEquals "mineminemineminemineminemine" "$got" "caller variables are not clobbered"
}

test_no_variable_leak
test_caller_variables_survive
