# gohugoio/hugo -- BSDs, Solaris, and build variants
#
# Assets look like:  hugo_0.165.0_linux-amd64.tar.gz
#                    hugo_extended_0.165.0_linux-arm64.tar.gz
#                    hugo_0.165.0_windows-amd64.zip
#
# Three things this shows that the other examples do not:
#
#   - the BSD family and Solaris: dragonfly, freebsd, netbsd, openbsd, solaris
#     -- plus illumos, which hugo does not publish for and which is mapped
#     onto the solaris build (see adjust_os)
#   - a VARIANT dimension that is neither OS nor arch.  Hugo publishes plain,
#     `extended`, `withdeploy` and `extended_withdeploy` builds; because
#     archive_name is a shell function, that is one more expansion rather than
#     a new config concept.  The variants cover far fewer platforms than the
#     plain build, so PLATFORMS is COMPUTED from the variant -- it is an
#     ordinary shell variable, so that costs nothing.
#   - macOS is published only as a .pkg, never a tarball, so darwin is
#     deliberately absent from PLATFORMS.  A mac user gets "no binary
#     published for darwin/arm64" instead of a 404 on a URL that never existed.
#
# Note the underscore/hyphen split: hugo_<version>_<os>-<arch>.
#
# Verified against v0.165.0 by listing the release's 36 assets and resolving
# every PLATFORMS entry, in every variant, against that list.

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
HUGO_VARIANT=${HUGO_VARIANT:-}

# These lists are in `uname_arch` spelling, NOT GOARCH: check_platform runs
# before adjust_arch, so it sees armv7, not the "arm" that names the file.
#
# darwin is absent on purpose: hugo ships macOS as a .pkg only.
#
# linux/armv6 is absent on purpose too.  Hugo publishes ONE arm build and it is
# GOARM=7 -- `go version -m hugo` out of hugo_0.165.0_linux-arm.tar.gz reports
# `build GOARM=7`.  A GOARM=7 binary dies with SIGILL on ARMv6 hardware (Pi 1,
# Pi Zero, Pi Zero W), so listing armv6 would trade a clear "no binary
# published" for an install that only fails when the user runs it.
#
# illumos IS listed even though hugo publishes no illumos asset: adjust_os
# maps it onto the solaris build.  Listed here in the uname_os spelling for
# the same reason as the arches -- check_platform runs before adjust_os.
#
# The variants are built for far fewer platforms than the plain build, so the
# list depends on HUGO_VARIANT.  Without that, `HUGO_VARIANT=_extended` on
# FreeBSD would pass check_platform and then 404 -- precisely what PLATFORMS
# exists to prevent.  No variant is built for solaris, so illumos is absent
# from that list too.
if [ -n "${HUGO_VARIANT}" ]; then
  PLATFORMS="linux/amd64 linux/arm64
             windows/amd64"
else
  PLATFORMS="dragonfly/amd64
             freebsd/amd64
             illumos/amd64
             linux/amd64 linux/arm64 linux/armv7
             netbsd/amd64
             openbsd/amd64
             solaris/amd64
             windows/amd64 windows/arm64"
fi

adjust_format() {
  case ${OS} in
    windows) FORMAT=zip ;;
  esac
}

# illumos runs the solaris build.
#
# Go treats solaris and illumos as separate GOOS values, but hugo publishes
# only solaris-amd64, and that binary is an ordinary dynamically linked
# Solaris executable: interpreter /lib/amd64/ld.so.1, NEEDED libsendfile.so,
# libsocket.so, libc.so, and no versioned symbol requirements -- all of which
# illumos provides.
#
# That is an argument, not a proof, so the OmniOS CI leg installs hugo through
# this very config and then executes the result.  If illumos ever diverges,
# that leg goes red rather than a user getting a binary that will not run.
#
# Confirmed on OmniOS r151054, 2026-08-28: the install resolved
# "0.165.0 for illumos/amd64", fetched hugo_0.165.0_solaris-amd64.tar.gz, and
# the binary ran -- reporting itself as "hugo v0.165.0 solaris/amd64".
adjust_os() {
  case ${OS} in
    illumos) OS=solaris ;;
  esac
}

# hugo publishes a single "arm" build; uname_arch is more specific.  Only
# armv7 can reach here -- PLATFORMS turns armv5 and armv6 away first, because
# that build is GOARM=7.
adjust_arch() {
  case ${ARCH} in
    armv7) ARCH=arm ;;
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
