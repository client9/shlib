#!/bin/sh

# uname_os converts `uname -s` into standard golang OS types
# golang types are used since they cover
# most platforms and are standardized while raw uname values vary
# wildly.  See complete list of values by running
# "go tool dist list"
#
# ## EXAMPLE
#
# ```bash
# OS=$(uname_os)
# ```
#
uname_os() {
  os=$(uname -s | tr '[:upper:]' '[:lower:]')

  # fixed up for https://github.com/client9/shlib/issues/3
  case "$os" in
    msys_nt*) os="windows" ;;
    mingw*) os="windows" ;;
  esac

  # Sun Solaris and derived OS (Illumos, Oracle Solaris) reports to be the very ancient SunOS via uname not what it actually is
  if [ "$os" = "sunos" ]; then
    # Current illumos versions have -o to check if they are illumos or Solaris without breaking most builds.
    if [ $(uname -o) == "illumos" ]; then
      os="illumos"
    else
      os="solaris"
    fi
  fi

  # other fixups here
  echo "$os"
}
