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

# lint the generated bundle too: it is what users actually run, and it can
# break in ways the individual files cannot (bad concatenation order).
if [ -f ./dist/shlib.sh ]; then
  echo "== shellcheck dist/ =="
  "$SHELLCHECK" -f gcc -s sh ./dist/shlib.sh || rc=1
fi

echo "== shfmt =="
if [ -n "$("$SHFMT" -ci -p -i 2 -l ./*.sh ./scripts/*.sh)" ]; then
  echo "not formatted - run 'make fmt' to fix:"
  "$SHFMT" -ci -p -i 2 -l ./*.sh ./scripts/*.sh
  rc=1
fi

exit $rc
