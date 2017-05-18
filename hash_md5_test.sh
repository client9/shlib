
source assert.sh
source is_command.sh
source hash_md5.sh

test1() {
  want="14758f1afd44c09b7992073ccf00b43d"
  got=`echo foobar | hash_md5`
  assertEquals "$want" "$got" "test1: md5 via stdin"
}

test2() {
  want="14758f1afd44c09b7992073ccf00b43d"
  got=`hash_md5 fixtures/sample1.txt`
  assertEquals "$want" "$got" "test2: md5 via file"
  rm -f $tmpfile
}

test3() {
  assertFalse "hash_md5 NONEXISTANT"  "test3: non-existant file returns not 0"
}


test1
test2
test3

