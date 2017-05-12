#!/bin/sh

# untar
#
# if you need to unpack in specific directory use a
# subshell and cd
#
# (cd /foo && untar mytarball.gz)
#
untar() {
  TARBALL=$1
  case ${TARBALL} in
  *.tar.gz|*.tgz)
    tar -xzf ${TARBALL}
    ;;
  *.tar)
    tar -xf ${TARBALL}
    ;;
  *.zip)
    unzip ${TARBALL}
    ;;
  *)
    echo "Unknown archive format for ${TARBALL}"
    exit 1
  esac
}
