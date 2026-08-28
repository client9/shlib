# securego/gosec -- the simple case
#
# Assets look like:  gosec_2.29.0_darwin_arm64.tar.gz
# Named exactly as uname_os/uname_arch spell them, tar.gz on every platform
# including windows, so no adjust_* hooks are needed at all.
#
# Verified against v2.29.0.

# Config fragments are consumed by the other concatenated parts, which the
# linter cannot see when checking one file alone.
# shellcheck disable=SC2034
OWNER=securego
REPO=gosec
BINARY=gosec
FORMAT=tar.gz
BINDIR=${BINDIR:-./bin}

PLATFORMS="darwin/amd64 darwin/arm64
           linux/amd64 linux/arm64 linux/ppc64le linux/s390x
           windows/amd64 windows/arm64"

archive_name() {
  echo "${BINARY}_${VERSION}_${OS}_${ARCH}"
}

checksum_name() {
  echo "${BINARY}_${VERSION}_checksums.txt"
}
