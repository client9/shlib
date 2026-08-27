#
# hash_md5: produce md5 hash in hex digits for file or stding
#
# DEPENDS:
#   log, is_command
#
# NB: do not pass /dev/stdin as a filename when reading stdin.  ksh93
# implements pipelines with socketpairs rather than pipes, and a socket
# cannot be reopened by path (open() returns ENXIO on Linux).  Calling the
# hasher with no file operand lets it read fd 0 directly, which is portable.
hash_md5() {
  if [ -z "$1" ]; then
    set --
  else
    set -- "$1"
  fi
  if is_command md5sum; then
    _shlib_sum=$(md5sum "$@" 2>/dev/null) || return 1
    echo "$_shlib_sum" | cut -d ' ' -f 1
  elif is_command md5; then
    md5 -q "$@" 2>/dev/null
  elif is_command openssl; then
    # "MD5(name)= <hash>" / "(stdin)= <hash>"; digest is the last field
    _shlib_sum=$(openssl dgst -md5 "$@") || return 1
    echo "$_shlib_sum" | awk '{print $NF}'
  else
    log_crit "hash_md5 unable to find command to compute md5 hash"
    return 1
  fi
}
