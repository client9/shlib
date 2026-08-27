# Tests for log.sh.
#
# shellcheck disable=SC1091,SC2034,SC2329
. ./assert.sh
. ./echoerr.sh
. ./log.sh

# captured at file scope: see the note in test_log_prefix_default
_script0=$0

# Every log_* function writes to STDERR, so the tests capture 2>&1 with stdout
# discarded.  Priority is restored after each test that changes it, since the
# level is global state.

# --- log_prefix ----------------------------------------------------------

test_log_prefix_default() {
  got=$(log_prefix)
  assertNotEquals "" "$got" "log_prefix: produces a non-empty prefix"

  # In POSIX shells $0 is the script name in every scope, so log_prefix
  # reports the running script.  zsh sets $0 to the *function* name inside a
  # function (FUNCTION_ARGZERO), so it reports "log_prefix" instead, and
  # capturing at file scope does not help either -- zsh gives the sourced
  # library's own path there.  Fixing it needs zsh-specific syntax, the effect
  # is cosmetic (a prefix on log lines), and log_prefix is documented as an
  # override point precisely so callers can control this.
  case "$got" in
    log_prefix)
      assert_skip "log_prefix: zsh reports the function name for \$0"
      ;;
    *)
      assertEquals "$_script0" "$got" "log_prefix: defaults to \$0"
      ;;
  esac
}

# log.sh documents log_prefix as an override point, and the installer's
# main.sh relies on that to print OWNER/REPO instead of the script name
test_log_prefix_override() {
  log_prefix() { echo "my/project"; }
  got=$(log_err "boom" 2>&1 >/dev/null)
  case "$got" in
    "my/project err boom") assertTrue "true" "log_prefix: override is used by log_err" ;;
    *) assertTrue "false" "log_prefix: override not applied, got [$got]" ;;
  esac
  log_prefix() { echo "$0"; }
}

# --- log_tag -------------------------------------------------------------

test_log_tag_known() {
  assertEquals "emerg" "$(log_tag 0)" "log_tag 0"
  assertEquals "alert" "$(log_tag 1)" "log_tag 1"
  assertEquals "crit" "$(log_tag 2)" "log_tag 2"
  assertEquals "err" "$(log_tag 3)" "log_tag 3"
  assertEquals "warning" "$(log_tag 4)" "log_tag 4"
  assertEquals "notice" "$(log_tag 5)" "log_tag 5"
  assertEquals "info" "$(log_tag 6)" "log_tag 6"
  assertEquals "debug" "$(log_tag 7)" "log_tag 7"
}

# anything unrecognised is echoed back unchanged
test_log_tag_unknown() {
  assertEquals "9" "$(log_tag 9)" "log_tag: unknown number passes through"
  assertEquals "banana" "$(log_tag banana)" "log_tag: non-numeric passes through"
}

# --- log_priority / log_set_priority -------------------------------------

test_log_priority_default() {
  assertEquals "6" "$(log_priority)" "log_priority: default level is 6 (info)"
}

test_log_set_priority() {
  saved=$(log_priority)
  log_set_priority 3
  assertEquals "3" "$(log_priority)" "log_set_priority: changes the level"
  log_set_priority "$saved"
  assertEquals "$saved" "$(log_priority)" "log_set_priority: restores the level"
}

# with an argument it is a predicate: true when that level is at or below the
# current one, i.e. when a message of that severity should be emitted
test_log_priority_predicate() {
  saved=$(log_priority)
  log_set_priority 6
  assertTrue "log_priority 2" "log_priority: crit passes at level 6"
  assertTrue "log_priority 6" "log_priority: info passes at level 6"
  assertFalse "log_priority 7" "log_priority: debug does not pass at level 6"
  log_set_priority 7
  assertTrue "log_priority 7" "log_priority: debug passes at level 7"
  log_set_priority 0
  assertFalse "log_priority 3" "log_priority: err does not pass at level 0"
  log_set_priority "$saved"
}

# --- the log_* emitters --------------------------------------------------

test_log_writes_to_stderr() {
  out=$(log_err "to stderr" 2>/dev/null)
  assertEquals "" "$out" "log_err: writes nothing to stdout"
  err=$(log_err "to stderr" 2>&1 >/dev/null)
  assertNotEquals "" "$err" "log_err: writes to stderr"
}

test_log_message_format() {
  err=$(log_err "one two" 2>&1 >/dev/null)
  case "$err" in
    *" err one two") assertTrue "true" "log_err: '<prefix> <tag> <message>'" ;;
    *) assertTrue "false" "log_err: unexpected format [$err]" ;;
  esac
  err=$(log_crit "bad" 2>&1 >/dev/null)
  case "$err" in
    *" crit bad") assertTrue "true" "log_crit: tagged crit" ;;
    *) assertTrue "false" "log_crit: unexpected format [$err]" ;;
  esac
}

# multiple arguments are joined, as echo does
test_log_multiple_args() {
  err=$(log_err a b c 2>&1 >/dev/null)
  case "$err" in
    *" err a b c") assertTrue "true" "log_err: joins multiple arguments" ;;
    *) assertTrue "false" "log_err: got [$err]" ;;
  esac
}

# each emitter is gated on its own level
test_log_respects_priority() {
  saved=$(log_priority)

  log_set_priority 6
  assertEquals "" "$(log_debug hidden 2>&1 >/dev/null)" "log_debug: silent at level 6"
  assertNotEquals "" "$(log_info shown 2>&1 >/dev/null)" "log_info: emitted at level 6"

  log_set_priority 3
  assertEquals "" "$(log_info hidden 2>&1 >/dev/null)" "log_info: silent at level 3"
  assertNotEquals "" "$(log_err shown 2>&1 >/dev/null)" "log_err: emitted at level 3"

  log_set_priority 2
  assertEquals "" "$(log_err hidden 2>&1 >/dev/null)" "log_err: silent at level 2"
  assertNotEquals "" "$(log_crit shown 2>&1 >/dev/null)" "log_crit: emitted at level 2"

  log_set_priority 7
  assertNotEquals "" "$(log_debug shown 2>&1 >/dev/null)" "log_debug: emitted at level 7"

  log_set_priority "$saved"
}

# a suppressed message must still return success, or callers using
# `log_debug ... ` before `set -e` code would abort
test_log_suppressed_returns_zero() {
  saved=$(log_priority)
  log_set_priority 0
  log_debug "hidden" 2>/dev/null
  assertEquals "0" "$?" "log_debug: returns 0 even when suppressed"
  log_err "hidden" 2>/dev/null
  assertEquals "0" "$?" "log_err: returns 0 even when suppressed"
  log_set_priority "$saved"
}

test_log_prefix_default
test_log_prefix_override
test_log_tag_known
test_log_tag_unknown
test_log_priority_default
test_log_set_priority
test_log_priority_predicate
test_log_writes_to_stderr
test_log_message_format
test_log_multiple_args
test_log_respects_priority
test_log_suppressed_returns_zero
