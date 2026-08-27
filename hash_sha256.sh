# hash_sha256: compute SHA256 of $1 or stdin
#
# ## Example
#
# ```bash
# $ hash_sha256 foobar.tar.gz
# 237982738471928379137
# ```
#
# note lack of pipes to make sure errors are
# caught regardless of shell settings
# sha256sum NOFILE | cut ...
# won't fail unless setpipefail is on
#
# NB: do not pass /dev/stdin as a filename when reading stdin.  ksh93
# implements pipelines with socketpairs rather than pipes, and a socket
# cannot be reopened by path (open() returns ENXIO on Linux).  Calling the
# hasher with no file operand lets it read fd 0 directly, which is portable.
hash_sha256() {
  if [ -z "$1" ]; then
    set --
  else
    set -- "$1"
  fi
  if is_command gsha256sum; then
    # mac homebrew, others
    hash=$(gsha256sum "$@") || return 1
    echo "$hash" | cut -d ' ' -f 1
  elif is_command sha256sum; then
    # gnu, busybox
    hash=$(sha256sum "$@") || return 1
    echo "$hash" | cut -d ' ' -f 1
  elif is_command shasum; then
    # darwin, freebsd?
    hash=$(shasum -a 256 "$@" 2>/dev/null) || return 1
    echo "$hash" | cut -d ' ' -f 1
  elif is_command openssl; then
    # openssl prints "SHA2-256(name)= <hash>" (openssl 3.x),
    # "SHA256(name)= <hash>" (1.x), or "(stdin)= <hash>" when reading stdin.
    # The digest is always the last field.
    hash=$(openssl dgst -sha256 "$@") || return 1
    echo "$hash" | awk '{print $NF}'
  else
    log_crit "hash_sha256 unable to find command to compute sha-256 hash"
    return 1
  fi
}

# hash_sha256_verify validates a binary against a checksum.txt file
#
#
hash_sha256_verify() {
  TARGET=$1
  checksums=$2

  if [ -z "$checksums" ]; then
    log_err "hash_sha256_verify checksum file not specified in arg2"
    return 1
  fi

  # http://stackoverflow.com/questions/2664740/extract-file-basename-without-path-and-extension-in-bash
  BASENAME=${TARGET##*/}

  # Match the filename field EXACTLY.  A plain `grep "$BASENAME" file` matches
  # anywhere on the line and treats the name as a regular expression, so a
  # checksum listed for "evil-foo.tgz" would happily verify "foo.tgz".
  #
  # Handles the usual coreutils/BSD spellings:
  #   <hash>  <name>     two spaces (text mode)
  #   <hash> *<name>     leading asterisk (binary mode)
  #   <hash>  ./<name>   leading ./ or any other directory prefix
  #
  # Filenames containing spaces are not supported; checksum tools escape
  # those and no release artifact we have seen uses them.
  want=$(awk -v name="$BASENAME" '
    {
      f = $2
      sub(/^\*/, "", f)
      sub(/.*\//, "", f)
      if (f == name) print $1
    }' "$checksums" 2>/dev/null)

  # if the file is not listed, $want will be empty
  if [ -z "$want" ]; then
    log_err "hash_sha256_verify unable to find checksum for '${TARGET}' in '${checksums}'"
    return 1
  fi

  # more than one entry for the same name means the checksum file is
  # ambiguous.  Refuse rather than silently picking one.
  nwant=$(printf '%s\n' "$want" | wc -l | tr -d ' ')
  if [ "$nwant" != "1" ]; then
    log_err "hash_sha256_verify multiple checksums for '${BASENAME}' in '${checksums}'"
    return 1
  fi

  got=$(hash_sha256 "$TARGET")
  if [ "$want" != "$got" ]; then
    log_err "hash_sha256_verify checksum for '$TARGET' did not verify ${want} vs $got"
    return 1
  fi
}
