#!/bin/sh

# uname_os: convert `uname -s` into shlib's canonical OS name
#
# Raw `uname -s` values vary wildly; the canonical names are the ones
# release artifacts are almost always named after.  The set is the one
# Go uses for GOOS -- that is where the convention came from, and
# staying compatible with it is worth doing -- but it is shlib's set,
# and it deviates where reality does.  See `uname_os_check` for the
# full list and the rule for adding to it.
#
# ## EXAMPLE
#
# ```bash
# OS=$(uname_os)
# ```
#
uname_os() {
  _shlib_os=$(uname -s | tr '[:upper:]' '[:lower:]')

  # fixed up for https://github.com/client9/shlib/issues/3
  case "$_shlib_os" in
    msys*) _shlib_os="windows" ;;
    mingw*) _shlib_os="windows" ;;
    cygwin*) _shlib_os="windows" ;;
    win*) _shlib_os="windows" ;; # for windows busybox and like # https://frippery.org/busybox/
  esac

  # Sun Solaris and derived OS (Illumos, Oracle Solaris) reports to be the very ancient SunOS via uname not what it actually is
  if [ "$_shlib_os" = "sunos" ]; then
    # Current illumos versions have -o to check if they are illumos or Solaris without breaking most builds.
    if [ "$(uname -o 2>/dev/null)" = "illumos" ]; then
      _shlib_os="illumos"
    else
      _shlib_os="solaris"
    fi
  fi

  # other fixups here
  echo "$_shlib_os"
}
