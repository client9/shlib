# gohugoio/hugo -- BSDs, Solaris, and build variants
#
# Assets look like:  hugo_0.165.0_linux-amd64.tar.gz
#                    hugo_extended_0.165.0_linux-arm64.tar.gz
#                    hugo_0.165.0_windows-amd64.zip
#
# Three things this shows that the other examples do not:
#
#   - the BSD family and Solaris: dragonfly, freebsd, netbsd, openbsd, solaris
#   - a VARIANT dimension that is neither OS nor arch.  Hugo publishes plain,
#     `extended`, `withdeploy` and `extended_withdeploy` builds; because
#     archive_name is a shell function, that is one more expansion rather than
#     a new config concept.
#   - macOS is published only as a .pkg, never a tarball, so darwin is
#     deliberately absent from PLATFORMS.  A mac user gets "no binary
#     published for darwin/arm64" instead of a 404 on a URL that never existed.
#
# Note the underscore/hyphen split: hugo_<version>_<os>-<arch>.
#
# Verified against v0.165.0.

# Config fragments are consumed by the other concatenated parts, which the
# linter cannot see when checking one file alone.
# shellcheck disable=SC2034
OWNER=gohugoio
REPO=hugo
BINARY=hugo
FORMAT=tar.gz
BINDIR=${BINDIR:-./bin}

# Which build to install.  Set to "_extended", "_withdeploy" or
# "_extended_withdeploy" for those variants; empty for the plain build.
# Only linux/amd64, linux/arm64 and windows/amd64 have variant builds.
HUGO_VARIANT=${HUGO_VARIANT:-}

# darwin is absent on purpose: hugo ships macOS as a .pkg only.
#
# Listed in canonical GOOS/GOARCH terms, because check_platform runs before
# adjust_arch folds armv6/armv7 into arm.
PLATFORMS="dragonfly/amd64
           freebsd/amd64
           linux/amd64 linux/arm64 linux/armv6 linux/armv7
           netbsd/amd64
           openbsd/amd64
           solaris/amd64
           windows/amd64 windows/arm64"

adjust_format() {
  case ${OS} in
    windows) FORMAT=zip ;;
  esac
}

# hugo publishes a single "arm" build; uname_arch is more specific
adjust_arch() {
  case ${ARCH} in
    armv5 | armv6 | armv7) ARCH=arm ;;
  esac
}

# underscores around the version, a hyphen between os and arch
archive_name() {
  echo "${BINARY}${HUGO_VARIANT}_${VERSION}_${OS}-${ARCH}"
}

# one checksums file covers every variant, and it is not variant-named
checksum_name() {
  echo "${BINARY}_${VERSION}_checksums.txt"
}
