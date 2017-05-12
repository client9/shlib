#!/bin/sh

# uname_arch converts `uname -m` back into standardized golang
# OS types.
#
# TODO: list the types
#
# ## NOTES
#
# * uses non-POSIX `local` however any semi-modern (uh last 15 years)
#   should support it.
# * ARM CPUs are not added here but should be
#
# ## EXAMPLE
# 
# ```bash
# ARCH=$(uname_arch)
# ```
#
# See latest at:
# https://github.com/client9/posixshell
#
uname_arch() {
  local arch=$(uname -m)
  case $arch in
    x86_64) arch="amd64" ;;
    x86)    arch="386" ;;
    i686)   arch="386" ;;
    i386)   arch="386" ;;
  esac
  echo ${arch}
}

# uname_os converts `uname -s` into standard golang OS types
#
# TODO: list the types, provide reference
#
# ## EXAMPLE
#
# ```bash
# OS=$(uname_os)
# ```
#
uname_os() {
  local os=$(uname -s | tr '[:upper:]' '[:lower:]')
  # other fixups here
  echo ${os}
}
