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

echo "== shfmt =="
if [ -n "$("$SHFMT" -ci -p -i 2 -l ./*.sh ./scripts/*.sh ./install/*.sh)" ]; then
  echo "not formatted - run 'make fmt' to fix:"
  "$SHFMT" -ci -p -i 2 -l ./*.sh ./scripts/*.sh ./install/*.sh
  rc=1
fi

exit $rc
