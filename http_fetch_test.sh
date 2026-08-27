# Tests for the fetch(1) branch of http_download.
#
# fetch is the FreeBSD base-system downloader; base ships neither curl nor
# wget.  These live in their own file because they stub `fetch` as a shell
# function, which would shadow the real one and break the live-network tests
# in http_download_test.sh.
#
# shellcheck disable=SC1091,SC2034,SC2329
. ./assert.sh
. ./is_command.sh
. ./echoerr.sh
. ./log.sh
. ./mktmpdir.sh
. ./http_download.sh

STUB_FETCH_ARGS=""
STUB_FETCH_ACCEPT=""

# stand in for fetch(1): record how it was called and write the output file
fetch() {
  STUB_FETCH_ARGS="$*"
  STUB_FETCH_ACCEPT="${HTTP_ACCEPT-}"
  _out=""
  _prev=""
  for _a in "$@"; do
    if [ "$_prev" = "-o" ]; then _out=$_a; fi
    _prev=$_a
  done
  test -z "$_out" || echo stub >"$_out"
  return 0
}

test_plain_download() {
  d=$(mktmpdir)
  http_download_fetch "$d/f" https://example.invalid/x
  assertEquals "0" "$?" "fetch: plain download returns 0"
  assertTrue "[ -f '$d/f' ]" "fetch: writes the output file"
  assertEquals "" "$STUB_FETCH_ACCEPT" "fetch: no Accept set when no header given"
  rm -rf "$d"
}

# fetch has no -H; Accept is the one header it can express, via HTTP_ACCEPT
test_accept_header() {
  d=$(mktmpdir)
  http_download_fetch "$d/f" https://example.invalid/x "Accept:application/json"
  assertEquals "application/json" "$STUB_FETCH_ACCEPT" "fetch: Accept maps to HTTP_ACCEPT"
  rm -rf "$d"
}

test_accept_header_with_space() {
  d=$(mktmpdir)
  http_download_fetch "$d/f" https://example.invalid/x "Accept: application/json"
  assertEquals "application/json" "$STUB_FETCH_ACCEPT" "fetch: leading space stripped from Accept"
  rm -rf "$d"
}

# Authorization has no fetch equivalent.  Failing loudly beats silently
# sending an unauthenticated request.
test_unsupported_header_fails() {
  d=$(mktmpdir)
  assertFalse "http_download_fetch '$d/f' https://example.invalid/x 'Authorization: token abc'" \
    "fetch: unsupported header fails rather than being dropped"
  rm -rf "$d"
}

# on a stock FreeBSD box there is no curl and no wget
test_dispatch_falls_through_to_fetch() {
  is_command() {
    case "$1" in
      curl | wget) return 1 ;;
      *) command -v "$1" >/dev/null ;;
    esac
  }
  d=$(mktmpdir)
  STUB_FETCH_ARGS=""
  http_download "$d/f" https://example.invalid/x >/dev/null 2>&1
  case "$STUB_FETCH_ARGS" in
    *example.invalid*) assertTrue "true" "dispatch: uses fetch when curl and wget are absent" ;;
    *) assertTrue "false" "dispatch: did not reach fetch (args=[$STUB_FETCH_ARGS])" ;;
  esac
  . ./is_command.sh
  rm -rf "$d"
}

# and curl still wins when it is present
test_dispatch_prefers_curl() {
  d=$(mktmpdir)
  STUB_FETCH_ARGS=""
  http_download "$d/f" https://raw.githubusercontent.com/client9/shlib/master/fixtures/sample1.txt >/dev/null 2>&1
  assertEquals "" "$STUB_FETCH_ARGS" "dispatch: curl is preferred over fetch when available"
  rm -rf "$d"
}

test_plain_download
test_accept_header
test_accept_header_with_space
test_unsupported_header_fails
test_dispatch_falls_through_to_fetch
test_dispatch_prefers_curl
