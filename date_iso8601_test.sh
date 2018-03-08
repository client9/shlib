. ./assert.sh
. ./is_command.sh
. ./date_iso8601.sh

test1() {
  now=$(date_iso8601)
  want="24"
  got=${#now}
  assertEquals "$want" "$got" "test1: iso8601 date is not 24 characters"
}

test1
