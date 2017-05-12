#!/bin/sh

# mktmpdir: create a tmp directory
#
# If TMPDIR is set, then create it if necessary
# If not set, make one with `mktemp -d`
mktmpdir() {
   test -z "$TMPDIR" && TMPDIR="$(mktemp -d)"
   mkdir -p ${TMPDIR}
   echo ${TMPDIR}
}
