#!/bin/sh
set -ex
shellcheck -f gcc -s sh *.sh
shellcheck -f gcc -s bash *.sh
shellcheck -f gcc -s dash *.sh
shellcheck -f gcc -s ksh *.sh
test -z "$(./bin/shfmt -p -i 2 -l *.sh)" || (echo "not formated"; exit 1)

