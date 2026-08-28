# Tests for the ftp(1) branch of http_download.
#
# ftp(1) is the base-system downloader on OpenBSD and NetBSD; neither ships
# curl or wget.  These live in their own file because they stub `ftp` as a
# shell function, which would shadow the real one and break the live-network
# tests in http_download_test.sh.
#
# Two different programs answer to the name `ftp`, and they differ in the one
# way that matters here: tnftp (NetBSD, DragonFly) has -H for arbitrary
# request headers, OpenBSD's ftp has no header support at all.  The library
# probes the binary's usage line rather than trusting `uname -s`, so the stub
# below emulates both usage lines and STUB_FTP_HAS_H selects which.
#
# shellcheck disable=SC1091,SC2034,SC2329
. ./assert.sh
. ./is_command.sh
. ./echoerr.sh
. ./log.sh
. ./mktmpdir.sh
. ./http_download.sh

# "yes" makes the stub advertise tnftp's -H; "no" makes it OpenBSD's ftp.
#
# Driven by a variable rather than by redefining the stub per test: ksh93
# does not honour a function redefined inside a subshell, and repeatedly
# redefining and unsetting functions has made it crash.
STUB_FTP_HAS_H="no"
STUB_FTP_ARGS=""
STUB_FTP_HEADER=""

# stand in for ftp(1): answer the capability probe, otherwise record how it
# was called and write the output file
ftp() {
  # the probe.  -Z is not a valid option in either real program, so both
  # print their usage line and exit.
  if [ "$1" = "-Z" ]; then
    if [ "$STUB_FTP_HAS_H" = "yes" ]; then
      echo "usage: ftp [-46AadefginpRtVv] [-b BUFSIZE] [-H HEADER] [-N NETRC] [-o OUTPUT]" >&2
    else
      echo "usage: ftp [-46AadEegiMmnptVv] [-D title] [-k seconds] [-o output]" >&2
    fi
    return 1
  fi

  STUB_FTP_ARGS="$*"
  STUB_FTP_HEADER=""
  _out=""
  _prev=""
  for _a in "$@"; do
    if [ "$_prev" = "-o" ]; then _out=$_a; fi
    if [ "$_prev" = "-H" ]; then STUB_FTP_HEADER=$_a; fi
    _prev=$_a
  done
  test -z "$_out" || echo stub >"$_out"
  return 0
}

test_plain_download() {
  d=$(mktmpdir)
  http_download_ftp "$d/f" https://example.invalid/x
  assertEquals "0" "$?" "ftp: plain download returns 0"
  assertTrue "[ -f '$d/f' ]" "ftp: writes the output file"
  assertEquals "" "$STUB_FTP_HEADER" "ftp: no header sent when none given"
  rm -rf "$d"
}

# -V is the only flag both programs accept for "be quiet"; OpenBSD's -M does
# not exist in tnftp.
test_plain_download_is_quiet() {
  d=$(mktmpdir)
  http_download_ftp "$d/f" https://example.invalid/x
  case "$STUB_FTP_ARGS" in
    *-V*) assertTrue "true" "ftp: passes -V" ;;
    *) assertTrue "false" "ftp: did not pass -V (args=[$STUB_FTP_ARGS])" ;;
  esac
  rm -rf "$d"
}

# tnftp: -H carries the header through verbatim
test_header_with_tnftp() {
  STUB_FTP_HAS_H="yes"
  d=$(mktmpdir)
  http_download_ftp "$d/f" https://example.invalid/x "Accept:application/json"
  assertEquals "0" "$?" "ftp: header download returns 0 when -H is supported"
  assertEquals "Accept:application/json" "$STUB_FTP_HEADER" "ftp: header passed via -H"
  STUB_FTP_HAS_H="no"
  rm -rf "$d"
}

test_authorization_with_tnftp() {
  STUB_FTP_HAS_H="yes"
  d=$(mktmpdir)
  http_download_ftp "$d/f" https://example.invalid/x "Authorization: token abc"
  assertEquals "Authorization: token abc" "$STUB_FTP_HEADER" "ftp: Authorization passed via -H"
  STUB_FTP_HAS_H="no"
  rm -rf "$d"
}

# OpenBSD's ftp has no -H.  Failing loudly beats silently dropping the header
# -- github_release without its Accept gets an HTML page, and github_api
# without its Authorization gets an unauthenticated request.
test_header_without_h_fails() {
  STUB_FTP_HAS_H="no"
  d=$(mktmpdir)
  STUB_FTP_HEADER=""
  assertFalse "http_download_ftp '$d/f' https://example.invalid/x 'Accept:application/json'" \
    "ftp: unsupported header fails rather than being dropped"
  assertEquals "" "$STUB_FTP_HEADER" "ftp: no request made when the header cannot be sent"
  rm -rf "$d"
}

# on a stock OpenBSD or NetBSD box there is no curl, no wget and no fetch
test_dispatch_falls_through_to_ftp() {
  is_command() {
    case "$1" in
      curl | wget | fetch) return 1 ;;
      *) command -v "$1" >/dev/null ;;
    esac
  }
  d=$(mktmpdir)
  STUB_FTP_ARGS=""
  http_download "$d/f" https://example.invalid/x >/dev/null 2>&1
  case "$STUB_FTP_ARGS" in
    *example.invalid*) assertTrue "true" "dispatch: uses ftp when curl, wget and fetch are absent" ;;
    *) assertTrue "false" "dispatch: did not reach ftp (args=[$STUB_FTP_ARGS])" ;;
  esac
  . ./is_command.sh
  rm -rf "$d"
}

# fetch wins over ftp.  DragonFly has both, and fetch is the one that can
# express an Accept header there.
test_dispatch_prefers_fetch() {
  is_command() {
    case "$1" in
      curl | wget) return 1 ;;
      fetch) return 0 ;;
      *) command -v "$1" >/dev/null ;;
    esac
  }
  fetch() { return 0; }
  d=$(mktmpdir)
  STUB_FTP_ARGS=""
  http_download "$d/f" https://example.invalid/x >/dev/null 2>&1
  assertEquals "" "$STUB_FTP_ARGS" "dispatch: fetch is preferred over ftp when available"
  . ./is_command.sh
  unset -f fetch
  rm -rf "$d"
}

test_plain_download
test_plain_download_is_quiet
test_header_with_tnftp
test_authorization_with_tnftp
test_header_without_h_fails
test_dispatch_falls_through_to_ftp
test_dispatch_prefers_fetch
