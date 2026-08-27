# golangci/golangci-lint -- 27 platforms, and the binary is nested in the archive
#
# Assets look like:  golangci-lint-2.13.1-darwin-arm64.tar.gz
#                    golangci-lint-2.13.1-windows-amd64.zip
#
# Two things make this the most demanding example:
#
#   - hyphens everywhere, including between the project name and the version
#   - the archive wraps its contents in a versioned directory, so the binary
#     is at golangci-lint-2.13.1-darwin-arm64/golangci-lint rather than at the
#     root.  That is what binary_path() is for.
#
# It also ships illumos, loong64 and riscv64 builds, which exercise the less
# common entries in uname_os/uname_arch.
#
# Verified against v2.13.1.

# Config fragments are consumed by the other concatenated parts, which the
# linter cannot see when checking one file alone.
# shellcheck disable=SC2034
OWNER=golangci
REPO=golangci-lint
BINARY=golangci-lint
FORMAT=tar.gz
BINDIR=${BINDIR:-./bin}

PLATFORMS="darwin/amd64 darwin/arm64
           freebsd/386 freebsd/amd64 freebsd/arm64 freebsd/armv6 freebsd/armv7
           illumos/amd64
           linux/386 linux/amd64 linux/arm64 linux/armv6 linux/armv7
           linux/loong64 linux/mips64 linux/mips64le linux/ppc64le
           linux/riscv64 linux/s390x
           netbsd/386 netbsd/amd64 netbsd/arm64 netbsd/armv6 netbsd/armv7
           windows/386 windows/amd64 windows/arm64"

adjust_format() {
  case ${OS} in
    windows) FORMAT=zip ;;
  esac
}

# hyphen-separated, and no "v" on the version
archive_name() {
  echo "${BINARY}-${VERSION}-${OS}-${ARCH}"
}

# the archive wraps everything in a directory named after the archive itself
binary_path() {
  echo "${NAME}/$1"
}

checksum_name() {
  echo "${BINARY}-${VERSION}-checksums.txt"
}
