. ./assert.sh
. ./is_command.sh
. ./echoerr.sh
. ./log.sh
. ./mktmpdir.sh
. ./untar.sh

# roundtrip <extension> <command that builds a file named "archive">
#
# If the archive cannot be built the format is skipped rather than failed:
# the compressor is simply not installed here.  (Note macOS has no `xz`
# binary but bsdtar links liblzma, so probing the tool directly would skip
# a format that actually works -- build success is the honest test.)
roundtrip() {
  ext=$1
  maker=$2
  d=$(mktmpdir) || return 1
  echo untar-fixture >"$d/payload.txt"
  if ! (cd "$d" && eval "$maker") >/dev/null 2>&1; then
    assert_skip "untar $ext: cannot build archive here"
    rm -rf "$d"
    return 0
  fi
  mkdir "$d/out"
  mv "$d/archive" "$d/out/archive$ext"
  (cd "$d/out" && untar "archive$ext") >/dev/null 2>&1
  rc=$?
  got=$(cat "$d/out/payload.txt" 2>/dev/null)
  rm -rf "$d"
  assertEquals "0" "$rc" "untar $ext: returns 0"
  assertEquals "untar-fixture" "$got" "untar $ext: contents restored"
}

test_tar() {
  roundtrip ".tar" "tar -cf archive payload.txt"
}

test_gz() {
  roundtrip ".tar.gz" "tar -czf archive payload.txt"
  roundtrip ".tgz" "tar -czf archive payload.txt"
}

test_bz2() {
  roundtrip ".tar.bz2" "tar -cjf archive payload.txt"
  roundtrip ".tbz" "tar -cjf archive payload.txt"
}

test_xz() {
  roundtrip ".tar.xz" "tar -cJf archive payload.txt"
  roundtrip ".txz" "tar -cJf archive payload.txt"
}

test_zst() {
  roundtrip ".tar.zst" "tar -cf t payload.txt && zstd -q t -o archive"
  roundtrip ".tzst" "tar -cf t payload.txt && zstd -q t -o archive"
}

test_zip() {
  roundtrip ".zip" "zip -q archive.zip payload.txt && mv archive.zip archive"
}

test_unknown() {
  assertFalse "untar some-file.rar" "unknown archive format returns non-zero"
  assertFalse "untar noextension" "no extension returns non-zero"
}

test_tar
test_gz
test_bz2
test_xz
test_zst
test_zip
test_unknown
