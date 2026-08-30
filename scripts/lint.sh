#!/bin/sh
#
# lint.sh: shellcheck every dialect we claim to support, then check formatting.
#
# Override the tool paths if they are not on PATH:
#   SHELLCHECK=./bin/shellcheck SHFMT=./bin/shfmt ./scripts/lint.sh
#
set -e

cd "$(dirname "$0")/.."

SHELLCHECK=${SHELLCHECK:-shellcheck}
SHFMT=${SHFMT:-./bin/shfmt}

# prefer a locally installed copy over PATH
if [ "$SHELLCHECK" = "shellcheck" ] && [ -x ./bin/shellcheck ]; then
  SHELLCHECK=./bin/shellcheck
fi

"$SHELLCHECK" -V | head -2

rc=0
for dialect in sh bash dash ksh; do
  echo "== shellcheck -s $dialect =="
  "$SHELLCHECK" -f gcc -s "$dialect" ./*.sh || rc=1
done

echo "== shellcheck -x scripts/ =="
"$SHELLCHECK" -x -f gcc -s sh ./scripts/*.sh || rc=1

echo "== shellcheck install/ =="
"$SHELLCHECK" -f gcc -s sh ./install/*.sh ./install/config.sh.example ./install/fixtures/*.sh || rc=1

# lint the generated bundle too: it is what users actually run, and it can
# break in ways the individual files cannot (bad concatenation order).
if [ -f ./dist/shlib.sh ]; then
  echo "== shellcheck dist/ =="
  "$SHELLCHECK" -f gcc -s sh ./dist/shlib.sh || rc=1

  # install-base.sh is only half an installer -- the project config supplies
  # PLATFORMS, archive_name and friends.  Lint the ASSEMBLED script, which is
  # what people actually run.
  if [ -f ./dist/install-base.sh ]; then
    _asm=$(mktemp)
    cat ./install/fixtures/config.sh ./dist/install-base.sh >"$_asm"
    # -e SC2329: log.sh documents log_prefix as an override point and main.sh
    # overrides it, so the default definition looks "never invoked".
    "$SHELLCHECK" -e SC2329 -f gcc -s sh "$_asm" || rc=1
    rm -f "$_asm"
  fi
fi

# Every bare `test_foo` invocation must have a matching `test_foo()`
# definition.  A lost definition otherwise prints "command not found" and the
# file can still report ok -- which has happened twice.
#
# Collected into a variable rather than setting rc inside the loop: a `while`
# on the right of a pipe runs in a subshell, so the assignment would be lost.
echo "== test invocations =="
_undefined=$(
  for t in ./*_test.sh; do
    sed -n 's/^\(test_[a-z0-9_]*\)$/\1/p' "$t" | while read -r fn; do
      grep -q "^${fn}() {" "$t" || echo "${t}: calls ${fn} but never defines it"
    done
  done
)
if [ -n "$_undefined" ]; then
  echo "$_undefined"
  rc=1
fi

# Flags that Solaris and illumos do not have.
#
# /usr/bin/grep there is the SVR4 one -- no -o, -E, -F, -x or -f -- POSIX head
# has only -n so `head -c` does not exist, POSIX find has no -maxdepth or
# -mindepth, and `sed -i` is a GNU extension.  None of these fail usefully:
# SVR4 head prints its usage line and exits 2, so a pipeline using it yields
# the usage text or nothing at all, and the bug shows up only when a Solaris
# leg runs -- or, for years, not at all.  `http_last_modified` shipped
# `tail -c 31 | head -c 29` and silently returned nothing there.
#
# Only files that actually run on Solaris are checked: the library, the tests
# and install/.  scripts/ is developer tooling and may use whatever is handy.
#
# Whole-line comments are stripped first (via sed, which preserves the line
# numbering) so that a comment explaining why NOT to use one of these does not
# trip the check -- the naive `grep head | grep -- -c` matches nothing else
# right now.  The tool must be in command position, so `--head`, `$_shlib_header`
# and the word "header" cannot match.
echo "== solaris-hostile flags =="
_svr4=$(
  for f in ./*.sh ./install/*.sh; do
    sed 's/^[[:space:]]*#.*//' "$f" | grep -nE \
      '(^|[|;&({])[[:space:]]*(head[[:space:]]+-c|grep[[:space:]]+-[a-zA-Z]*[oEFxf]|find[[:space:]].*-(max|min)depth|sed[[:space:]]+-i)' |
      sed "s|^|${f}:|"
  done
)
if [ -n "$_svr4" ]; then
  echo "$_svr4"
  echo "these flags do not exist on Solaris/illumos - see docs/PORTABILITY.md"
  rc=1
fi

echo "== shfmt =="
if [ -n "$("$SHFMT" -ci -p -i 2 -l ./*.sh ./scripts/*.sh ./install/*.sh)" ]; then
  echo "not formatted - run 'make fmt' to fix:"
  "$SHFMT" -ci -p -i 2 -l ./*.sh ./scripts/*.sh ./install/*.sh
  rc=1
fi

exit $rc
