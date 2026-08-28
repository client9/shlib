#!/bin/sh
#
# install-tools.sh: download pinned shellcheck + shfmt into ./bin
#
# Replaces the old scripts/godownloader-shfmt.sh.  godownloader is archived
# (https://github.com/goreleaser/godownloader) and the generated script carried
# a stale, forked copy of this library.  This script instead *sources* shlib
# itself, so a regression in the library breaks the build -- which is the point.
#
set -e

cd "$(dirname "$0")/.."

. ./is_command.sh
. ./echoerr.sh
. ./log.sh
. ./uname_os.sh
. ./uname_arch.sh
. ./uname_os_check.sh
. ./uname_arch_check.sh
. ./http_download.sh

SHELLCHECK_VERSION=${SHELLCHECK_VERSION:-v0.11.0}
SHFMT_VERSION=${SHFMT_VERSION:-v3.13.1}
BINDIR=${BINDIR:-./bin}

uname_os_check
uname_arch_check

OS=$(uname_os)
ARCH=$(uname_arch)

# upstream shellcheck publishes x86_64/aarch64, not the names uname_arch
# returns -- the same round-trip an installer does with adjust_arch
case "$ARCH" in
  amd64) sc_arch="x86_64" ;;
  arm64) sc_arch="aarch64" ;;
  *)
    log_crit "install-tools: no shellcheck build for arch '$ARCH'"
    exit 1
    ;;
esac

mkdir -p "$BINDIR"
tmp=$(mktemp -d)
# expand $tmp now, not at trap time -- that is the point
# shellcheck disable=SC2064
trap "rm -rf '$tmp'" EXIT INT TERM

install_shellcheck() {
  name="shellcheck-${SHELLCHECK_VERSION}.${OS}.${sc_arch}.tar.xz"
  url="https://github.com/koalaman/shellcheck/releases/download/${SHELLCHECK_VERSION}/${name}"
  log_info "downloading $url"
  http_download "${tmp}/${name}" "$url"
  # NB: untar() does not yet handle .tar.xz -- see issue backlog
  (cd "$tmp" && tar -xJf "$name")
  install "${tmp}/shellcheck-${SHELLCHECK_VERSION}/shellcheck" "${BINDIR}/shellcheck"
  log_info "installed ${BINDIR}/shellcheck"
}

install_shfmt() {
  name="shfmt_${SHFMT_VERSION}_${OS}_${ARCH}"
  url="https://github.com/mvdan/sh/releases/download/${SHFMT_VERSION}/${name}"
  log_info "downloading $url"
  http_download "${tmp}/${name}" "$url"
  install "${tmp}/${name}" "${BINDIR}/shfmt"
  log_info "installed ${BINDIR}/shfmt"
}

install_shellcheck
install_shfmt

"${BINDIR}/shellcheck" -V | head -2
"${BINDIR}/shfmt" --version
