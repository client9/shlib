#!/bin/sh
#
# dist.sh: build the concatenated shlib bundles into ./dist
#
# Produces:
#   dist/shlib.sh       full bundle, comments intact
#   dist/shlib.min.sh   comments stripped, for embedding in install scripts
#   dist/checksums.txt  sha256 of both
#
# These are committed to the repo so that consumers can fetch a stable raw URL
# at build time instead of hand-vendoring a copy that goes stale.  Because they
# are generated files under version control, CI runs `make dist` and then
# `git diff --exit-code dist/` to prove they are in sync with the sources.
#
set -e

cd "$(dirname "$0")/.."

. ./is_command.sh
. ./echoerr.sh
. ./log.sh
. ./hash_sha256.sh

DISTDIR=${DISTDIR:-./dist}

# Dependency order.  Function definitions are order-independent at runtime, but
# listing dependencies first documents what needs what -- and is the order the
# README tells people to use.
FILES="license.sh
is_command.sh
echoerr.sh
log.sh
uname_os.sh
uname_arch.sh
uname_os_check.sh
uname_arch_check.sh
mktmpdir.sh
untar.sh
http_download.sh
http_last_modified.sh
github_api.sh
github_release.sh
hash_md5.sh
hash_sha256.sh
hash_sha512.sh
date_iso8601.sh
git_clone_or_update.sh
license_end.sh"

# CalVer, read from the VERSION file.
#
# Deliberately NOT derived from `git log` or `date -u`.  Both were tried and
# both break the CI sync check that proves dist/ matches its sources:
#
#   date -u        changes daily, so dist/ would show a diff every day
#   git log        counts only *committed* history, but this script bundles the
#                  working tree -- so editing a library file and running
#                  `make dist` leaves the version behind, and the version then
#                  bumps the moment you commit, making the freshly committed
#                  dist/ instantly stale.  Chicken-and-egg.
#
# A plain file is stable, needs no git, and works in shallow clones and source
# tarballs.  Bump it when cutting a release.
VERSION=${VERSION:-$(cat ./VERSION 2>/dev/null || true)}
if [ -z "$VERSION" ]; then
  log_crit "dist unable to read ./VERSION; set VERSION= to override"
  exit 1
fi

mkdir -p "$DISTDIR"

# The version marker lives in a `cat /dev/null <<EOF` heredoc, not a '#'
# comment, so that it survives the comment-stripping pipeline below.  This is
# the same trick license.sh uses to keep attribution in stripped bundles.
emit_preamble() {
  echo "cat /dev/null <<EOF"
  echo "shlib ${VERSION}"
  echo "https://github.com/client9/shlib"
  echo "EOF"
}

# shellcheck disable=SC2086
emit_bundle() {
  emit_preamble
  cat $FILES
}

emit_bundle >"${DISTDIR}/shlib.sh"

# same pipeline the README documents for hand-rolled bundles
emit_bundle | grep -v '^#' | grep -v ' #' | tr -s '\n' >"${DISTDIR}/shlib.min.sh"

# checksums, computed with our own hash_sha256
(
  cd "$DISTDIR"
  for f in shlib.sh shlib.min.sh; do
    echo "$(hash_sha256 "$f")  $f"
  done
) >"${DISTDIR}/checksums.txt"

log_info "dist shlib ${VERSION}"
for f in shlib.sh shlib.min.sh; do
  log_info "dist ${DISTDIR}/${f} ($(wc -l <"${DISTDIR}/${f}" | tr -d ' ') lines)"
done
