#!/bin/sh
#
# dist.sh: build the concatenated shlib bundles into ./dist
#
# Produces:
#   dist/shlib.sh        the function library, comments intact
#   dist/install-base.sh shlib + the installer flow; prepend a config
#   dist/checksums.txt   sha256 of both
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
install_exe.sh
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

# The version marker lives in a `cat /dev/null <<EOF` heredoc rather than a '#'
# comment.  That began as a way to survive comment stripping, which no longer
# happens -- it stays because the documented way to date a vendored copy is
#
#   sed -n 's/^shlib \(.*\)/\1/p' their-install.sh
#
# and that pattern must keep matching copies already in the wild.  license.sh
# uses the same trick for the same reason.
emit_preamble() {
  echo "cat /dev/null <<EOF"
  echo "shlib ${VERSION}"
  echo "https://github.com/client9/shlib"
  echo "EOF"
}

# shellcheck disable=SC2086
emit_bundle() {
  emit_preamble
  # shellcheck disable=SC2086
  cat $FILES
}

emit_bundle >"${DISTDIR}/shlib.sh"

# NOTHING IS STRIPPED.  There used to be a `shlib.min.sh` built by piping the
# bundle through `grep -v '^[[:space:]]*#'`, and it was a bad trade:
#
#   - It shipped a silently broken release.  The original idiom also filtered
#     ` #`, which deleted CODE lines carrying trailing comments -- v2026.08.27
#     went out with valid checksums and no `win*) os="windows"` mapping, and
#     no `gitrepo=` assignments in git_clone_or_update.
#   - Even the fixed version constrains what the library may contain: any
#     embedded awk, sed or python carrying a whole-line `#` would be silently
#     gutted.
#   - It bought about 10 KB gzipped, once, at install time.  GitHub raw serves
#     gzip; the TLS handshake costs more than the difference.
#   - A `curl | sh` script that people are told to read before running is more
#     useful WITH its comments.
#
# So the bundles carry their comments, and the only transformation here is
# concatenation.

# install-base.sh: everything a downstream install script needs except its own
# config.  Consumers do:  cat config.sh install-base.sh > install.sh
#
# Order matters.  main.sh runs the flow and must come last, so that a truncated
# `curl | sh` cannot execute a partial install.
{
  emit_preamble
  # shellcheck disable=SC2086
  cat $FILES
  cat install/runner.sh
  cat install/main.sh
} >"${DISTDIR}/install-base.sh"

# checksums, computed with our own hash_sha256
(
  cd "$DISTDIR"
  for f in shlib.sh install-base.sh; do
    echo "$(hash_sha256 "$f")  $f"
  done
) >"${DISTDIR}/checksums.txt"

log_info "dist shlib ${VERSION}"
for f in shlib.sh install-base.sh; do
  log_info "dist ${DISTDIR}/${f} ($(wc -l <"${DISTDIR}/${f}" | tr -d ' ') lines)"
done
