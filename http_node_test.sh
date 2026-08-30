# Tests for the node branch of http_download.
#
# The companion to http_python_test.sh.  node:22-slim ships neither curl, wget
# nor python3 -- only node, and a perl with no TLS -- so this branch is the
# only thing that can fetch anything there.
#
# In its own file because the dispatch tests stub `node` as a shell function,
# which would shadow the real interpreter and break the live tests above them.
#
# shellcheck disable=SC1091,SC2034,SC2329
. ./assert.sh
. ./is_command.sh
. ./echoerr.sh
. ./log.sh
. ./mktmpdir.sh
. ./http_download.sh

FIXTURE_URL=https://raw.githubusercontent.com/client9/shlib/master/fixtures/sample1.txt

have_node() {
  command -v node >/dev/null 2>&1 || command -v nodejs >/dev/null 2>&1
}

# --- real interpreter ------------------------------------------------------

test_real_download() {
  if ! have_node; then
    assert_skip "http_download_node: no node installed"
    return 0
  fi
  d=$(mktmpdir)
  http_download_node "$d/f" "$FIXTURE_URL"
  assertEquals "0" "$?" "node: plain download returns 0"
  assertEquals "foobar" "$(cat "$d/f" 2>/dev/null)" "node: writes the body to the file"
  rm -rf "$d"
}

# fetch() takes arbitrary headers, so like the python branch -- and unlike
# fetch(1) and both ftp(1)s -- github_release can resolve "latest" here.
test_real_accept_header() {
  if ! have_node; then
    assert_skip "http_download_node: no node installed"
    return 0
  fi
  d=$(mktmpdir)
  http_download_node "$d/j" https://github.com/client9/shlib/releases/latest \
    "Accept: application/json"
  case "$(head -c 1 "$d/j" 2>/dev/null)" in
    "{") assertTrue "true" "node: Accept header is honoured (JSON, not HTML)" ;;
    *) assertTrue "false" "node: Accept ignored; got [$(head -c 40 "$d/j" 2>/dev/null)]" ;;
  esac
  rm -rf "$d"
}

test_real_404_fails() {
  if ! have_node; then
    assert_skip "http_download_node: no node installed"
    return 0
  fi
  d=$(mktmpdir)
  assertFalse "http_download_node '$d/nope' https://raw.githubusercontent.com/client9/shlib/master/NOSUCHFILE" \
    "node: a 404 returns non-zero"
  assertFalse "[ -f '$d/nope' ]" "node: a 404 leaves no file behind"
  rm -rf "$d"
}

# Release downloads redirect to objects.githubusercontent.com.  This is why
# the branch uses fetch() and not the https module, which does not follow
# redirects -- so it is worth pinning that a cross-host redirect really works.
test_real_redirect() {
  if ! have_node; then
    assert_skip "http_download_node: no node installed"
    return 0
  fi
  d=$(mktmpdir)
  http_download_node "$d/c" \
    https://github.com/securego/gosec/releases/download/v2.29.0/gosec_2.29.0_checksums.txt
  assertEquals "0" "$?" "node: follows a cross-host redirect to a release asset"
  assertTrue "[ -s '$d/c' ]" "node: the redirected body lands in the file"
  rm -rf "$d"
}

# Run the live tests HERE, before the stub below exists.  A shell defines a
# function when execution reaches it, so a stub defined at the bottom is
# already in effect by the time a bottom-of-file invocation list runs.
test_real_download
test_real_accept_header
test_real_404_fails
test_real_redirect

# --- dispatch --------------------------------------------------------------

STUB_NODE_ARGS=""

# The caller invokes:  node -e PROGRAM dest url header
# Record only the positional arguments -- "$*" would embed the whole program.
node() {
  STUB_NODE_ARGS="${3-} ${4-} ${5-}"
  test -z "${3-}" || echo stub >"$3"
  return 0
}
nodejs() { node "$@"; }

# node:22-slim: a runtime, and no downloader of any kind
test_dispatch_falls_through_to_node() {
  is_command() {
    case "$1" in
      curl | wget | fetch | ftp | python3) return 1 ;;
      *) command -v "$1" >/dev/null ;;
    esac
  }
  d=$(mktmpdir)
  STUB_NODE_ARGS=""
  http_download "$d/f" https://example.invalid/x >/dev/null 2>&1
  case "$STUB_NODE_ARGS" in
    *example.invalid*) assertTrue "true" "dispatch: uses node when nothing else exists" ;;
    *) assertTrue "false" "dispatch: did not reach node (args=[$STUB_NODE_ARGS])" ;;
  esac
  . ./is_command.sh
  rm -rf "$d"
}

# python3 is tried before node, so an image carrying both is deterministic
test_dispatch_prefers_python() {
  if ! command -v python3 >/dev/null 2>&1; then
    assert_skip "dispatch: no python3 installed; nothing to prefer"
    return 0
  fi
  is_command() {
    case "$1" in
      curl | wget | fetch | ftp) return 1 ;;
      *) command -v "$1" >/dev/null ;;
    esac
  }
  d=$(mktmpdir)
  STUB_NODE_ARGS=""
  http_download "$d/f" https://example.invalid/x >/dev/null 2>&1
  assertEquals "" "$STUB_NODE_ARGS" "dispatch: python3 is preferred over node"
  . ./is_command.sh
  rm -rf "$d"
}

test_dispatch_falls_through_to_node
test_dispatch_prefers_python
