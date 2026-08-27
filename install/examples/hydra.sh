# ory/hydra -- renamed OS and ARCH, and a different archive format on windows
#
# Assets look like:  hydra_26.2.0-macOS_arm64.tar.gz
#                    hydra_26.2.0-linux_64bit.tar.gz
#                    hydra_26.2.0-windows_64bit.zip
#
# Three things differ from the canonical spelling:
#   - a hyphen between version and OS, not an underscore
#   - darwin is spelled macOS, amd64 is 64bit, 386 is 32bit
#   - windows ships .zip while everything else ships .tar.gz
#
# Verified against v26.2.0.

# Config fragments are consumed by the other concatenated parts, which the
# linter cannot see when checking one file alone.
# shellcheck disable=SC2034
OWNER=ory
REPO=hydra
BINARY=hydra
FORMAT=tar.gz
BINDIR=${BINDIR:-./bin}

PLATFORMS="darwin/amd64 darwin/arm64
           linux/386 linux/amd64 linux/arm64 linux/armv6 linux/armv7
           windows/386 windows/amd64 windows/arm64"

adjust_format() {
  case ${OS} in
    windows) FORMAT=zip ;;
  esac
}

adjust_os() {
  case ${OS} in
    darwin) OS=macOS ;;
  esac
}

adjust_arch() {
  case ${ARCH} in
    386) ARCH=32bit ;;
    amd64) ARCH=64bit ;;
  esac
}

# note the hyphen, not an underscore
archive_name() {
  echo "${BINARY}_${VERSION}-${OS}_${ARCH}"
}

checksum_name() {
  echo "checksums.txt"
}
