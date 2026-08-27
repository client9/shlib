. ./assert.sh
. ./is_command.sh
. ./echoerr.sh
. ./log.sh
. ./hash_md5.sh

test1() {
  want="14758f1afd44c09b7992073ccf00b43d"
  got=$(echo foobar | hash_md5)
  assertEquals "$want" "$got" "test1: md5 via stdin"
}

test2() {
  want="14758f1afd44c09b7992073ccf00b43d"
  got=$(hash_md5 fixtures/sample1.txt)
  assertEquals "$want" "$got" "test2: md5 via file"
}

test3() {
  assertFalse "hash_md5 NONEXISTANT" "test3: non-existent file returns not 0"
}

test1
test2
test3

# --- openssl fallback (was a TODO in hash_md5.sh) -------------------------
test4() {
  if ! command -v openssl >/dev/null 2>&1; then
    assert_skip "test4: openssl not installed"
    return 0
  fi
  is_command() {
    case "$1" in
      md5sum | md5) return 1 ;;
      *) command -v "$1" >/dev/null ;;
    esac
  }
  want="14758f1afd44c09b7992073ccf00b43d"
  got=$(echo foobar | hash_md5)
  assertEquals "$want" "$got" "test4: openssl fallback via stdin"
  got=$(hash_md5 fixtures/sample1.txt)
  assertEquals "$want" "$got" "test4a: openssl fallback via file"
  . ./is_command.sh
}

test4
