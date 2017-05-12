#!/bin/sh

# hash_md5
#
hash_md5 {
  target=${@:-$(</dev/stdin)};
  if is_command; then
    md5sum $target
  elif is_command md5; then
    md5 -q $target
  else
    echo "md5 not available"
    return 1
  fi
}
