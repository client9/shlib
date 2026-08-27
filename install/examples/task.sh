# go-task/task -- no version in the archive name
#
# Assets look like:  task_darwin_arm64.tar.gz
#                    task_windows_amd64.zip
#
# Two things to note:
#   - the archive name carries no version at all, which a naive
#     "{name}_{version}_{os}_{arch}" template cannot express
#   - the project builds GOARCH "arm", while uname_arch reports armv6/armv7,
#     so those need folding back
#
# Verified against v3.53.1.

# Config fragments are consumed by the other concatenated parts, which the
# linter cannot see when checking one file alone.
# shellcheck disable=SC2034
OWNER=go-task
REPO=task
BINARY=task
FORMAT=tar.gz
BINDIR=${BINDIR:-./bin}

PLATFORMS="darwin/amd64 darwin/arm64
           freebsd/386 freebsd/amd64 freebsd/armv6 freebsd/armv7 freebsd/arm64
           linux/386 linux/amd64 linux/armv6 linux/armv7 linux/arm64 linux/riscv64
           windows/386 windows/amd64 windows/arm64"

adjust_format() {
  case ${OS} in
    windows) FORMAT=zip ;;
  esac
}

# the project publishes plain "arm"; uname_arch is more specific
adjust_arch() {
  case ${ARCH} in
    armv5 | armv6 | armv7) ARCH=arm ;;
  esac
}

archive_name() {
  echo "${BINARY}_${OS}_${ARCH}"
}

checksum_name() {
  echo "${BINARY}_checksums.txt"
}
