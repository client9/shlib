. ./is_command.sh
. ./echoerr.sh
. ./log.sh
. ./http_download.sh
. ./assert.sh

# test normal 200
test1() {
  http_download /dev/null https://raw.githubusercontent.com/client9/shlib/master/README.md
  assertEquals "$?" "0" "return != 0 on valid URL"
}

# test 404, missing
test2() {
  http_download /dev/null https://raw.githubusercontent.com/client9/shlib/master/does_not_exist
  assertNotEquals "$?" "0" "expected return to be non-zero on 404"
}

test1
test2
