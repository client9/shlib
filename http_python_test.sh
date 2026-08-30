# Tests for the python3 branch of http_download.
#
# python3 is not a base-system tool on any platform shlib targets.  This branch
# exists for container images, which routinely ship a language runtime and no
# downloader: python:3.12-slim, debian:stable-slim, ubuntu:24.04 and
# node:22-slim all have neither curl nor wget.
#
# In its own file because the dispatch tests stub `python3` as a shell
# function, which would shadow the real interpreter and break the live tests
# above them.
#
# shellcheck disable=SC1091,SC2034,SC2329
. ./assert.sh
. ./is_command.sh
. ./echoerr.sh
. ./log.sh
. ./mktmpdir.sh
. ./http_download.sh

FIXTURE_URL=https://raw.githubusercontent.com/client9/shlib/master/fixtures/sample1.txt

# --- real interpreter ------------------------------------------------------

test_real_download() {
  if ! command -v python3 >/dev/null 2>&1; then
    assert_skip "http_download_python: no python3 installed"
    return 0
  fi
  d=$(mktmpdir)
  http_download_python "$d/f" "$FIXTURE_URL"
  assertEquals "0" "$?" "python: plain download returns 0"
  assertEquals "foobar" "$(cat "$d/f" 2>/dev/null)" "python: writes the body to the file"
  rm -rf "$d"
}

# The reason this branch matters beyond "some box has no curl": urllib can send
# arbitrary headers, which neither fetch(1) nor either ftp(1) can.  So it is
# the only fallback on which github_release can resolve "latest" -- GitHub
# returns the HTML release page without `Accept: application/json`.
test_real_accept_header() {
  if ! command -v python3 >/dev/null 2>&1; then
    assert_skip "http_download_python: no python3 installed"
    return 0
  fi
  d=$(mktmpdir)
  http_download_python "$d/j" https://github.com/client9/shlib/releases/latest \
    "Accept: application/json"
  case "$(head -c 1 "$d/j" 2>/dev/null)" in
    "{") assertTrue "true" "python: Accept header is honoured (JSON, not HTML)" ;;
    *) assertTrue "false" "python: Accept ignored; got [$(head -c 40 "$d/j" 2>/dev/null)]" ;;
  esac
  rm -rf "$d"
}

# A 404 must fail loudly.  The failure mode worth guarding is writing the error
# page into the destination and reporting success, which is how a checksum
# mismatch becomes the user's first clue.
test_real_404_fails() {
  if ! command -v python3 >/dev/null 2>&1; then
    assert_skip "http_download_python: no python3 installed"
    return 0
  fi
  d=$(mktmpdir)
  assertFalse "http_download_python '$d/nope' https://raw.githubusercontent.com/client9/shlib/master/NOSUCHFILE" \
    "python: a 404 returns non-zero"
  assertFalse "[ -f '$d/nope' ]" "python: a 404 leaves no file behind"
  rm -rf "$d"
}

# Run the live tests HERE, before the stub below exists.
#
# A shell defines a function when execution reaches it, so a stub defined at
# the bottom of the file is already in effect by the time a bottom-of-file
# invocation list runs -- which silently turned every test above into a test of
# the stub.  Stubs cannot be scoped with ( ) either, because ksh93 does not
# honour a function redefined inside a subshell, so ordering is the tool.
test_real_download
test_real_accept_header
test_real_404_fails

# --- dispatch --------------------------------------------------------------

STUB_PY_ARGS=""

# Stand in for the interpreter.  The caller invokes
#
#   python3 -c PROGRAM dest url header
#
# so the interesting arguments are positional: $3 $4 $5.  Do NOT record "$*" --
# that embeds the whole program text, and an earlier version of this stub then
# tried to open it as a filename ("File name too long").
python3() {
  STUB_PY_ARGS="${3-} ${4-} ${5-}"
  test -z "${3-}" || echo stub >"$3"
  return 0
}

# a container image with a runtime and no downloader at all
test_dispatch_falls_through_to_python() {
  is_command() {
    case "$1" in
      curl | wget | fetch | ftp) return 1 ;;
      *) command -v "$1" >/dev/null ;;
    esac
  }
  d=$(mktmpdir)
  STUB_PY_ARGS=""
  http_download "$d/f" https://example.invalid/x >/dev/null 2>&1
  case "$STUB_PY_ARGS" in
    *example.invalid*) assertTrue "true" "dispatch: uses python3 when no base downloader exists" ;;
    *) assertTrue "false" "dispatch: did not reach python3 (args=[$STUB_PY_ARGS])" ;;
  esac
  . ./is_command.sh
  rm -rf "$d"
}

# python3 is last: every branch above it is a base-system tool on its platform,
# and this one is an application runtime that merely happens to be installed.
test_dispatch_prefers_base_tools() {
  if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    assert_skip "dispatch: no curl or wget installed; nothing to prefer"
    return 0
  fi
  d=$(mktmpdir)
  STUB_PY_ARGS=""
  http_download "$d/f" https://example.invalid/x >/dev/null 2>&1
  assertEquals "" "$STUB_PY_ARGS" "dispatch: a base downloader is preferred over python3"
  rm -rf "$d"
}

test_dispatch_falls_through_to_python
test_dispatch_prefers_base_tools
