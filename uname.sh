#!/bin/sh

# uname_arch converts `uname -m` back into golang
# OS types
#
# TODO: ARM types
# 
uname_arch() {
  ARCH=$(uname -m)
  case $ARCH in
    x86_64) ARCH="amd64" ;;
    x86)    ARCH="386" ;;
    i686)   ARCH="386" ;;
    i386)   ARCH="386" ;;
  esac
  echo ${ARCH}
}

# uname_os converts `uname -s` into standard golang OS types
#
uname_os() {
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  # other fixups here
  echo ${OS}
}
