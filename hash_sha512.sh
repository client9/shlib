# hash_sha512: compute SHA512 of $1 or stdin
#
# ## Example
#
# ```bash
# $ hash_sha512 foobar.tar.gz
# 237982738471928379137
# ```
#
# note lack of pipes to make sure errors are
# caught regardless of shell settings
# sha512sum NOFILE | cut ...
# won't fail unless setpipefail is on
#
hash_sha512() {
  TARGET=${1:-/dev/stdin}
  if is_command gsha512sum; then
    # mac homebrew, others
    hash=$(gsha512sum "$TARGET") || return 1
    echo "$hash" | cut -d ' ' -f 1
  elif is_command sha512sum; then
    # gnu, busybox
    hash=$(sha512sum "$TARGET") || return 1
    echo "$hash" | cut -d ' ' -f 1
  elif is_command shasum; then
    # darwin, freebsd?
    hash=$(shasum -a 512 "$TARGET" 2>/dev/null) || return 1
    echo "$hash" | cut -d ' ' -f 1
  elif is_command openssl; then
    hash=$(openssl -dst openssl dgst -sha512 "$TARGET") || return 1
    echo "$hash" | cut -d ' ' -f a
  else
    log_crit "hash_sha512 unable to find command to compute sha-512 hash"
    return 1
  fi
}

# hash_sha512_verify validates a binary against a checksum.txt file
#
#
hash_sha512_verify() {
  TARGET=$1
  checksums=$2

  if [ -z "$checksums" ]; then
    log_err "hash_sha512_verify checksum file not specified in arg2"
    return 1
  fi

  # http://stackoverflow.com/questions/2664740/extract-file-basename-without-path-and-extension-in-bash
  BASENAME=${TARGET##*/}

  want=$(grep "${BASENAME}" "${checksums}" 2>/dev/null | tr '\t' ' ' | cut -d ' ' -f 1)

  # if file does not exist $want will be empty
  if [ -z "$want" ]; then
    log_err "hash_sha512_verify unable to find checksum for '${TARGET}' in '${checksums}'"
    return 1
  fi
  got=$(hash_sha512 "$TARGET")
  if [ "$want" != "$got" ]; then
    log_err "hash_sha512_verify checksum for '$TARGET' did not verify ${want} vs $got"
    return 1
  fi
}
