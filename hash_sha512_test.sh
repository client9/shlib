. ./assert.sh
. ./is_command.sh
. ./echoerr.sh
. ./log.sh
. ./hash_sha512.sh

test1() {
  want="e79b8ad22b34a54be999f4eadde2ee895c208d4b3d83f1954b61255d2556a8b73773c0dc0210aa044ffcca6834839460959cbc9f73d3079262fc8bc935d46262"
  got=$(echo foobar | hash_sha512)
  assertEquals "$want" "$got" "test1: sha512 via stdin"
}

test2() {
  want="496e89d6b3f349464e9f8e7e831a3c30c13675f45a28cf9c052e4be10bc77885ab4762d9d7cd2f6bd542898429f91c85f7bf4a435c7a763e64e146652c3ac0d5"
  got=$(hash_sha512 ./fixtures/sample2.txt)
  assertEquals "$want" "$got" "test2: sha512 via file"
}

test3() {
  assertFalse "hash_sha512 NONEXISTANT" "test3: non-existent file returns not 0"
}

test4() {
  assertFalse "hash_sha512_verify arg1" "test4: 1-arg input failed"
}

test5() {
  assertFalse "hash_sha512_verify arg1 arg2" "test5: no checksum file fails"
}

test6() {
  assertTrue "hash_sha512_verify fixtures/sample1.txt fixtures/sha512-checksums.txt" "test6: verify file using checksums"
}

test7() {
  assertFalse "hash_sha512_verify fixtures/sample1.txt fixtures/empty.txt" "test7: verify file using empty file fails"
}

test8() {
  assertFalse "hash_sha512_verify fixtures/sample1.txt fixtures/sha512-checksums-wrong.txt" "test8: verify file using wrong checksum file fails"
}
test1
test2
test3
test4
test5
test6
test7
test8
