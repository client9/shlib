assertTrue() {
  if ! eval "$1"; then
    echo "assertTrue failed: $2"
    exit 2
  fi
}

assertFalse() {
  if eval "$1"; then
    echo "assertFalse failed: $2"
    exit 2
  fi
}

assertEquals() {
  want=$1
  got=$2
  msg=$3
  if [ "$want" != "$got" ]; then
    echo "assertEquals failed: want='$want' got='$got' $msg"
    exit 2
  fi
}

assertNotEquals() {
  want=$1
  got=$2
  msg=$3
  if [ "$want" = "$got" ]; then
    echo "assertNotEquals failed: want='$want' got='$got' $msg"
    exit 2
  fi
}
