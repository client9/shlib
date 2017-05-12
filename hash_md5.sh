#!/bin/sh

# hash_md5
#
hash_md5 {
  target=${@:-$(</dev/stdin)};
  if type md5sum &> /dev/null; then
    md5sum $target
  elif type md5 &> /dev/null; then
    md5 -q $target
  else
    echo "md5 not available"
    return 1
  fi
}
