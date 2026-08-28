# Every documented call form must survive `set -u`.
#
# An install script is exactly the kind of thing people run under `set -eu`,
# and so is CI: the vmactions runner executes its `run:` block that way, which
# is how this whole class of bug surfaced. Under nounset a bare `$2` for an
# OPTIONAL argument is not a warning, it aborts the shell -- so
# `github_release owner/repo` (tag omitted, which is the documented form) took
# the NetBSD and OpenBSD legs down before a single test ran.
#
# The functions here are the ones with an optional argument or an optional
# environment variable. A required argument is not covered: omitting it is
# caller error, and aborting is a reasonable thing to do about it.
#
# shellcheck disable=SC1091,SC2034,SC2329
. ./assert.sh
. ./is_command.sh
. ./echoerr.sh
. ./log.sh
. ./mktmpdir.sh
. ./hash_md5.sh
. ./hash_sha256.sh
. ./hash_sha512.sh
. ./http_download.sh
. ./github_api.sh
. ./github_release.sh
. ./install_exe.sh
. ./untar.sh
. ./uname_os.sh
. ./uname_arch.sh
. ./date_iso8601.sh

# nounset_ok CODE -- true if CODE runs to COMPLETION under `set -u`
#
# The sentinel is what makes this meaningful. A nounset violation stops
# execution on the spot so the echo never happens; an ordinary non-zero return
# still reaches it. Without the sentinel this could not tell "aborted" from
# "returned 1", and several of the functions below are expected to return 1.
#
# The sentinel is appended INSIDE the eval string, not written after the eval.
# ksh93 and zsh confine a nounset abort to the eval itself and carry on with
# the enclosing subshell, where sh/dash/bash tear the whole subshell down. So
# a sentinel outside the eval is reached on ksh93 and zsh no matter what, and
# every assertion here would pass vacuously on exactly the shells that most
# need checking. test_detects_a_violation is what caught that.
nounset_ok() {
  _nu_got=$( (
    set -u
    eval "$1"" ; echo __completed__"
  ) 2>/dev/null)
  case "$_nu_got" in
    *__completed__*) return 0 ;;
  esac
  return 1
}

# Stubs for anything that would otherwise touch the network. They are defined
# at the top level and never redefined: ksh93 does not honour a function
# redefined inside a subshell, and `set -u` runs inside one here.
curl() { return 0; }
wget() { return 0; }
fetch() { return 0; }
ftp() { return 0; }
http_copy() { echo '{"tag_name":"v2026.01.01"}'; }

# --- the guard itself -----------------------------------------------------

# Prove the harness can actually detect a violation, otherwise every assertion
# below would pass vacuously.
test_detects_a_violation() {
  assertFalse "nounset_ok 'unset _nu_absent; echo \"\$_nu_absent\"'" \
    "nounset_ok: reports an unset expansion as a failure"
  assertTrue "nounset_ok 'echo hello'" \
    "nounset_ok: reports ordinary code as ok"
  assertTrue "nounset_ok 'false'" \
    "nounset_ok: a non-zero return is not a nounset violation"
}

# --- optional arguments ---------------------------------------------------

# the documented stdin form takes no argument at all
test_hash_from_stdin() {
  assertTrue "nounset_ok 'hash_md5 </dev/null'" "hash_md5: no argument"
  assertTrue "nounset_ok 'hash_sha256 </dev/null'" "hash_sha256: no argument"
  assertTrue "nounset_ok 'hash_sha512 </dev/null'" "hash_sha512: no argument"
}

# arg2 is checked for emptiness, so calling without it is a supported path
# that must report an error rather than abort
test_hash_verify_without_checksum_file() {
  assertTrue "nounset_ok 'hash_sha256_verify fixtures/sample1.txt'" \
    "hash_sha256_verify: missing arg2 reports, not aborts"
  assertTrue "nounset_ok 'hash_sha512_verify fixtures/sample1.txt'" \
    "hash_sha512_verify: missing arg2 reports, not aborts"
}

# arg3 is documented as "optional extra header"
test_http_download_without_header() {
  assertTrue "nounset_ok 'http_download_curl /dev/null https://example.invalid/x'" \
    "http_download_curl: no header argument"
  assertTrue "nounset_ok 'http_download_wget /dev/null https://example.invalid/x'" \
    "http_download_wget: no header argument"
  assertTrue "nounset_ok 'http_download_fetch /dev/null https://example.invalid/x'" \
    "http_download_fetch: no header argument"
  assertTrue "nounset_ok 'http_download_ftp /dev/null https://example.invalid/x'" \
    "http_download_ftp: no header argument"
  assertTrue "nounset_ok 'http_download /dev/null https://example.invalid/x'" \
    "http_download: no header argument"
}

# http_copy's header is optional too
test_http_copy_without_header() {
  assertTrue "nounset_ok 'http_copy https://example.invalid/x'" \
    "http_copy: no header argument"
}

# the one that actually broke CI: the tag is optional and defaults to "latest"
test_github_release_without_tag() {
  assertTrue "nounset_ok 'github_release client9/shlib'" \
    "github_release: no tag argument"
}

# --- optional environment -------------------------------------------------

# GITHUB_TOKEN is opt-in; an unauthenticated request is the normal case
test_github_api_without_token() {
  assertTrue "nounset_ok 'unset GITHUB_TOKEN; github_api /dev/null https://api.github.com/x'" \
    "github_api: GITHUB_TOKEN unset"
}

# ASSERT_VERBOSE is opt-in, and assert.sh is sourced by every test file
test_assert_without_verbose() {
  assertTrue "nounset_ok 'unset ASSERT_VERBOSE; _assert_ok probe'" \
    "assert.sh: ASSERT_VERBOSE unset"
}

# --- no-argument functions ------------------------------------------------

# log_priority is documented as "if no args, return the priority"
test_log_priority_without_args() {
  assertTrue "nounset_ok 'log_priority'" "log_priority: no argument"
  assertTrue "nounset_ok 'log_debug hello'" "log_debug: still fine"
  assertTrue "nounset_ok 'uname_os'" "uname_os: no argument"
  assertTrue "nounset_ok 'uname_arch'" "uname_arch: no argument"
  assertTrue "nounset_ok 'mktmpdir'" "mktmpdir: no argument"
  assertTrue "nounset_ok 'date_iso8601'" "date_iso8601: no argument"
}

# --- the installer --------------------------------------------------------

# An install script is the most likely thing to be run under `set -eu`, and
# `curl ... | sh` with no tag argument is its normal invocation.
test_installer_without_optional_config() {
  # posh's getopts misbehaves when the shell has no positional parameters and
  # the code is reached through `-c`/eval, which is exactly how nounset_ok
  # runs: it walks garbage, reports `invalid option -- ''`, and parse_args
  # takes its `\?` branch into usage, which exits 2 before the sentinel.
  # That is a posh quirk in this harness, not a shlib bug -- verified by
  # running a real assembled installer under posh, where `-b DIR` and an
  # explicit tag both parse correctly.  Skipped rather than asserted falsely,
  # the same way log_test.sh skips \$0 under zsh.
  if [ -n "${POSH_VERSION-}" ]; then
    assert_skip "parse_args: posh getopts is unreliable under -c/eval"
  else
    assertTrue "nounset_ok '. ./install/runner.sh; parse_args'" \
      "parse_args: no tag argument"
  fi
  assertTrue "nounset_ok '. ./install/runner.sh; unset PLATFORMS; normalize_platforms'" \
    "normalize_platforms: PLATFORMS unset"
  assertTrue "nounset_ok '. ./install/runner.sh; unset PLATFORMS; check_platform'" \
    "check_platform: PLATFORMS unset"
  assertTrue "nounset_ok '. ./install/runner.sh; unset TAG; latest_version() { echo v1; }; RELEASES_URL=x; tag_to_version'" \
    "tag_to_version: TAG unset"
  # FORMAT is optional: a project publishing bare binaries has no suffix to
  # append, and may never assign it at all.
  assertTrue "nounset_ok '. ./install/runner.sh; NAME=widget; unset FORMAT; tarball_name'" \
    "tarball_name: FORMAT unset"
}

test_detects_a_violation
test_hash_from_stdin
test_hash_verify_without_checksum_file
test_http_download_without_header
test_http_copy_without_header
test_github_release_without_tag
test_github_api_without_token
test_assert_without_verbose
test_log_priority_without_args
test_installer_without_optional_config
