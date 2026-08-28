# hadolint/hadolint -- a release with no archive at all
#
# Assets look like:  hadolint-linux-x86_64
#                    hadolint-macos-arm64
#                    hadolint-windows-x86_64.exe
#                    checksums.sha256
#
# Every other example downloads an archive and extracts a binary from it.
# hadolint publishes the binaries THEMSELVES -- no tarball, no zip, nothing to
# unpack.  That is what the `unpack` hook is for:
#
#   unpack() { :; }                       there is nothing to extract
#   binary_path() { echo "${TARBALL}"; }  the download already IS the binary
#
# Four things this shows that no other example does:
#
#   - NO ARCHIVE.  FORMAT is empty, so the filename has no suffix at all.
#   - A SUFFIX THAT IS NOT AN ARCHIVE.  The windows asset ends in `.exe`, so
#     FORMAT=exe -- non-empty, and still nothing to unpack.  This is exactly
#     why unpacking is its own hook rather than a "FORMAT=binary" sentinel:
#     one field cannot say ".exe" and "do not extract" at the same time.
#   - MIXED SPELLINGS IN ONE PROJECT.  x86_64 is the raw `uname -m` name, but
#     the 64-bit ARM asset is `arm64`, which is Go's.  So adjust_arch remaps
#     one and leaves the other alone.  Naming conventions are not a package
#     deal, which is the whole reason adjust_arch is a function.
#   - A `*filename` CHECKSUM FILE.  checksums.sha256 is written in binary mode
#     (`<hash> *<name>`) rather than the usual two spaces.  hash_sha256_verify
#     already strips the asterisk, so this needs no special handling.
#
# The bare download arrives without an execute bit -- a tar member would have
# carried one.  install_exe chmods 0755 on the way in, so that is handled too.
#
# Verified against v2.15.1.

# Config fragments are consumed by the other concatenated parts, which the
# linter cannot see when checking one file alone.
# shellcheck disable=SC2034
OWNER=hadolint
REPO=hadolint
BINARY=hadolint
# no suffix on unix; adjust_format adds one for windows
FORMAT=""
BINDIR=${BINDIR:-./bin}

# In `uname_os`/`uname_arch` spelling, NOT the spelling in the filenames:
# check_platform runs before the adjust_* hooks.
PLATFORMS="darwin/amd64 darwin/arm64
           linux/amd64 linux/arm64
           windows/amd64"

# The windows build is the one asset with a suffix.  It is still not an
# archive -- see unpack below.
adjust_format() {
  case ${OS} in
    windows) FORMAT=exe ;;
  esac
}

adjust_os() {
  case ${OS} in
    darwin) OS=macos ;;
  esac
}

# Only amd64 is remapped.  hadolint names the x86 build with the raw kernel
# spelling (x86_64) but the ARM build with Go's (arm64), so arm64 passes
# through untouched.
adjust_arch() {
  case ${ARCH} in
    amd64) ARCH=x86_64 ;;
  esac
}

# no version in the name at all
archive_name() {
  echo "${BINARY}-${OS}-${ARCH}"
}

# one file covers every platform, and it is not version-named
checksum_name() {
  echo "checksums.sha256"
}

# There is no archive: the downloaded file is the binary.
unpack() { :; }

# ...so the binary is at the download itself.  The argument is ignored on
# purpose -- it names the binary to install ("hadolint", or "hadolint.exe" on
# windows), but there is no archive to look for it inside.
binary_path() {
  echo "${TARBALL}"
}
