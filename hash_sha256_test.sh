. ./assert.sh
. ./is_command.sh
. ./echoerr.sh
. ./log.sh
. ./hash_sha256.sh

test1() {
  want="aec070645fe53ee3b3763059376134f058cc337247c978add178b6ccdfb0019f"
  got=$(echo foobar | hash_sha256)
  assertEquals "$want" "$got" "test1: sha256 via stdin"
}

test2() {
  want="7fd1e028e43640e9762bb51b5d8c80e0a3fe9beb2481c7cfcccc175b3b051b69"
  got=$(hash_sha256 ./fixtures/sample2.txt)
  assertEquals "$want" "$got" "test2: sha256 via file"
}

test3() {
  assertFalse "hash_sha256 NONEXISTANT" "test3: non-existent file returns not 0"
}

test4() {
  assertFalse "hash_sha256_verify arg1" "test4: 1-arg input failed"
}

test5() {
  assertFalse "hash_sha256_verify arg1 arg2" "test5: no checksum file fails"
}

test6() {
  assertTrue "hash_sha256_verify fixtures/sample1.txt fixtures/sha256-checksums.txt" "test6: verify file using checksums"
}

test7() {
  assertFalse "hash_sha256_verify fixtures/sample1.txt fixtures/empty.txt" "test7: verify file using empty file fails"
}

test8() {
  assertFalse "hash_sha256_verify fixtures/sample1.txt fixtures/sha256-checksums-wrong.txt" "test8: verify file using wrong checksum file fails"
}
test1
test2
test3
test4
test5
test6
test7
test8

# --- regression tests for the unanchored-grep bug -------------------------
# A checksum file listing only "evil-sample1.txt" must NOT verify
# "sample1.txt".  The old `grep "$BASENAME"` matched it as a substring.
test9() {
  assertFalse "hash_sha256_verify fixtures/sample1.txt fixtures/sha256-checksums-substring.txt" \
    "test9: checksum listed for a different file must not verify"
}

# "." in the filename is a regex metacharacter; "sampleXtxt" must not match
test10() {
  assertFalse "hash_sha256_verify fixtures/sampleXtxt fixtures/sha256-checksums.txt" \
    "test10: filename must be matched literally, not as a regex"
}

# two entries for the same name is ambiguous - refuse rather than guess
test11() {
  assertFalse "hash_sha256_verify fixtures/sample1.txt fixtures/sha256-checksums-dup.txt" \
    "test11: duplicate entries must be refused"
}

# legitimate spellings that must still verify
test12() {
  assertTrue "hash_sha256_verify fixtures/sample1.txt fixtures/sha256-checksums-binary.txt" \
    "test12: binary-mode '*name' entry verifies"
}

test13() {
  assertTrue "hash_sha256_verify fixtures/sample1.txt fixtures/sha256-checksums-dotslash.txt" \
    "test13: './name' entry verifies"
}

# caller passes a path; only the basename should be looked up
test14() {
  assertTrue "hash_sha256_verify ./fixtures/sample1.txt fixtures/sha256-checksums.txt" \
    "test14: path argument resolves to basename"
}

test9
test10
test11
test12
test13
test14

# --- openssl fallback -----------------------------------------------------
# This branch never worked: it ran `openssl -dst openssl dgst -...` and then
# `cut -f a`, an illegal field spec.  Force it by hiding the other hashers.
test15() {
  if ! command -v openssl >/dev/null 2>&1; then
    assert_skip "test15: openssl not installed"
    return 0
  fi
  is_command() {
    case "$1" in
      gsha256sum | sha256sum | shasum) return 1 ;;
      *) command -v "$1" >/dev/null ;;
    esac
  }
  want="aec070645fe53ee3b3763059376134f058cc337247c978add178b6ccdfb0019f"
  got=$(echo foobar | hash_sha256)
  assertEquals "$want" "$got" "test15: openssl fallback via stdin"
  got=$(hash_sha256 fixtures/sample1.txt)
  assertEquals "$want" "$got" "test15a: openssl fallback via file"
  assertFalse "hash_sha256 NONEXISTANT" "test15b: openssl fallback fails on missing file"
  . ./is_command.sh
}

test15
