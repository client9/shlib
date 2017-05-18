
source assert.sh
source is_command.sh
source hash_sha256.sh

test1() {
  want="aec070645fe53ee3b3763059376134f058cc337247c978add178b6ccdfb0019f"
  got=`echo foobar | hash_sha256`
  assertEquals "$want" "$got" "test1: sha256 via stdin"
}

test2() {
  want="7fd1e028e43640e9762bb51b5d8c80e0a3fe9beb2481c7cfcccc175b3b051b69"
  got=`hash_sha256 ./fixtures/sample2.txt`
  assertEquals "$want" "$got" "test2: sha256 via file"
}

test3() {
  assertFalse "hash_sha256 NONEXISTANT"  "test3: non-existent file returns not 0"
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

