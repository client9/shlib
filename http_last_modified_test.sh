# Tests for http_last_modified.
#
# curl is stubbed with synthetic header blocks, so these are deterministic and
# need no network -- which is also why this function went untested for so long,
# and why it shipped a `head -c` that does not exist on Solaris.
#
# shellcheck disable=SC1091,SC2034,SC2329
. ./assert.sh
. ./is_command.sh
. ./echoerr.sh
. ./log.sh
. ./http_last_modified.sh

STUB_HEADERS=""

# stand in for curl --head: emit a canned response header block
curl() {
  printf '%s' "$STUB_HEADERS"
}

test_http11_header() {
  STUB_HEADERS=$(printf 'HTTP/1.1 200 OK\r\nLast-Modified: Sat, 30 Sep 2017 07:16:26 GMT\r\nContent-Type: text/plain\r\n\r\n')
  assertEquals "Sat, 30 Sep 2017 07:16:26 GMT" "$(http_last_modified https://example.invalid/x)" \
    "http_last_modified: parses an HTTP/1.1 Last-Modified"
}

# HTTP/2 lowercases every header name
test_http2_lowercase_header() {
  STUB_HEADERS=$(printf 'HTTP/2 200\r\nlast-modified: Sat, 30 Sep 2017 07:16:26 GMT\r\n\r\n')
  assertEquals "Sat, 30 Sep 2017 07:16:26 GMT" "$(http_last_modified https://example.invalid/x)" \
    "http_last_modified: parses a lowercased HTTP/2 last-modified"
}

# the CR must not survive into the result
test_no_carriage_return() {
  STUB_HEADERS=$(printf 'HTTP/1.1 200 OK\r\nLast-Modified: Sat, 30 Sep 2017 07:16:26 GMT\r\n\r\n')
  got=$(http_last_modified https://example.invalid/x | tr -d '\n' | od -c | sed -n '1p')
  case "$got" in
    *'\r'*) assertTrue "false" "http_last_modified: carriage return leaked into the result" ;;
    *) assertTrue "true" "http_last_modified: strips the trailing carriage return" ;;
  esac
}

# a server that does not send the field yields nothing, not a stray fragment
test_absent_header() {
  STUB_HEADERS=$(printf 'HTTP/2 200\r\ndate: Sun, 30 Aug 2026 16:35:26 GMT\r\nexpires: Sun, 30 Aug 2026 16:40:26 GMT\r\n\r\n')
  assertEquals "" "$(http_last_modified https://example.invalid/x)" \
    "http_last_modified: absent field yields empty, not a fragment of another header"
}

# a name that merely ends in the field name must not match
test_similar_header_not_matched() {
  STUB_HEADERS=$(printf 'HTTP/1.1 200 OK\r\nX-Last-Modified-By: someone\r\n\r\n')
  assertEquals "" "$(http_last_modified https://example.invalid/x)" \
    "http_last_modified: anchors on the field name, not a substring"
}

test_http11_header
test_http2_lowercase_header
test_no_carriage_return
test_absent_header
test_similar_header_not_matched
