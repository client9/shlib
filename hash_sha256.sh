#
# portable posix shell sha256 routines
#

hash_sha256() {
  TARGET=$1
  if type gsha256sum &> /dev/null; then
    # mac homebrew, others
    gsha256sum $TARGET | cut -d ' ' -f 1
  elif type sha256sum &> /dev/null; then
    # gnu, busybox
    sha256sum $TARGET | cut -d ' ' -f 1
  elif type shasum &> /dev/null; then
    # darwin, freebsd?
    shasum -a 256 $TARGET | cut -d ' ' -f 1
  elif type openssl &> /dev/null; then
    openssl -dst openssl dgst -sha256 $TARGET | cut -d ' ' -f a
  else
    echo "Unable to compute hash. exiting"
    exit 1
  fi
}

# hash_sha256_verify validates a binary against a checksum.txt file
hash_sha256_verify() {
  TARGET=$1
  SUMS=$2

  # http://stackoverflow.com/questions/2664740/extract-file-basename-without-path-and-extension-in-bash
  BASENAME=${TARGET##*/}

  # remove tabs:  old version of goreleaser used them
  WANT=$(grep ${BASENAME} ${SUMS} | tr '\t' ' ' | cut -d ' ' -f 1)
  GOT=$(sha256 $TARGET)
  if [ "$GOT" != "$WANT" ]; then
     echo "Checksum for $TARGET did not verify"
     echo "WANT: ${WANT}"
     echo "GOT : ${GOT}"
     exit 1
  fi
}
