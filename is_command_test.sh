. ./is_command.sh
. ./assert.sh

test1() {
  assertTrue "is_command ls" "test1 'ls' exists"
}

test2() {
  assertFalse "is_command junk" "test2 'junk' does not exist"
}

test3() {
  assertTrue "is_command junk" "test3 function 'junk' exists"
}

test1
test2

# define missing function
junk() {
  return 0
}

test3
