# koalaman/shellcheck -- not a Go project
#
# Assets look like:  shellcheck-v0.11.0.darwin.aarch64.tar.gz
#                    shellcheck-v0.11.0.linux.x86_64.tar.gz
#                    shellcheck-v0.11.0.linux.armv6hf.tar.gz
#                    shellcheck-v0.11.0.zip
#
# shellcheck is written in Haskell, and it is here to show that nothing in
# this installer is Go-specific.  Four things it shows that the Go examples
# do not:
#
#   - RAW KERNEL ARCH SPELLINGS.  The assets say `x86_64` and `aarch64`, the
#     names `uname -m` actually reports, rather than the `amd64`/`arm64` that
#     Go-built projects use.  uname_arch normalises those away, so adjust_arch
#     maps them straight back.  This is the round trip a non-Go project pays
#     for shlib's canonical vocabulary, and it is two lines.
#   - THE TAG, NOT THE VERSION.  Every other example interpolates ${VERSION}
#     (no leading v).  These filenames carry the tag verbatim -- v0.11.0 --
#     so this one uses ${TAG}.  Both are set before archive_name runs.
#   - DOTS AS SEPARATORS, and a platform field that is `os.arch`.
#   - A WINDOWS ASSET OF AN ENTIRELY DIFFERENT SHAPE.  The unix tarballs are
#     <name>.<os>.<arch>.tar.gz with the binary in a versioned directory; the
#     windows build is a single shellcheck-v0.11.0.zip carrying no os or arch
#     at all, with shellcheck.exe at the root.  So archive_name and
#     binary_path both branch on OS.  A `case` inside a function body is fine
#     under bash 3.2 -- the parser bug is lexical, and only bites when the
#     `case` is written inline inside a $( ).
#
# There is NO checksums file: shellcheck publishes none, so checksum_name is
# omitted rather than pointed at a URL that 404s.  This is the one example
# that installs unverified, and that is a property of the project, not a
# recommendation.
#
# Verified against v0.11.0 by listing the release's assets and by building and
# running the installer.

# Config fragments are consumed by the other concatenated parts, which the
# linter cannot see when checking one file alone.
# shellcheck disable=SC2034
OWNER=koalaman
REPO=shellcheck
BINARY=shellcheck
# .tar.xz is published too, and is smaller.  tar.gz is chosen because untar's
# xz branch needs `tar -J`, which busybox tar does not always have.
FORMAT=tar.gz
BINDIR=${BINDIR:-./bin}

# In `uname_arch` spelling, NOT the spelling in the filenames: check_platform
# runs before adjust_arch.
#
# armv7 is deliberately absent.  The published ARM build is `armv6hf` and an
# ARMv6 hard-float binary does run on ARMv7 hardware, but this repo does not
# assert an ABI it has not executed on that ABI, so an armv7 user gets a clear
# "no binary published" rather than an untested claim.
PLATFORMS="darwin/amd64 darwin/arm64
           linux/amd64 linux/arm64 linux/armv6 linux/riscv64
           windows/amd64"

adjust_format() {
  case ${OS} in
    windows) FORMAT=zip ;;
  esac
}

# Map shlib's canonical names back to the raw `uname -m` spellings the
# filenames use.  This is the inverse of what uname_arch just did.
adjust_arch() {
  case ${ARCH} in
    amd64) ARCH=x86_64 ;;
    arm64) ARCH=aarch64 ;;
    armv6) ARCH=armv6hf ;;
  esac
}

# windows is one arch-less zip; everything else is <name>.<os>.<arch>
archive_name() {
  case ${OS} in
    windows) echo "${BINARY}-${TAG}" ;;
    *) echo "${BINARY}-${TAG}.${OS}.${ARCH}" ;;
  esac
}

# The tarballs wrap everything in shellcheck-v0.11.0/; the zip does not.
#
# Note this is NOT ${NAME}/$1, the way golangci-lint's is.  There the wrapper
# directory happens to equal the archive name; here the archive is
# shellcheck-v0.11.0.linux.x86_64 while the directory inside it is just
# shellcheck-v0.11.0.  Assuming the two always coincide is the mistake this
# example exists to make visible -- install_test.sh caught it.
binary_path() {
  case ${OS} in
    windows) echo "$1" ;;
    *) echo "${BINARY}-${TAG}/$1" ;;
  esac
}
