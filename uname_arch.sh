# uname_arch: convert `uname -m` into shlib's canonical architecture name
#
# The canonical names are the ones release artifacts are almost always
# named after (`amd64`, `arm64`), not the raw `uname -m` string.  The
# set is the one Go uses for GOARCH -- that is where the convention
# came from -- but it is shlib's set; notably ARM is spelled out by
# version rather than folded into `arm` the way Go does.
#
# A project whose assets use the raw kernel spellings (`x86_64`,
# `aarch64`) maps back with the installer's `adjust_arch` hook.
#
# See also `uname_arch_check` for a self-check
#
# ## NOTES
#
# Notes on ARM:
# arm 5,6,7: uname is of form `armv6l`, ` armv7l` where a letter
# or something else is after the number. Has examples:
# https://github.com/golang/go/wiki/GoArm
# https://en.wikipedia.org/wiki/List_of_ARM_microarchitectures
#
# arm8 is known as arm64 and aarch64
#
# more notes: https://github.com/golang/go/issues/13669
#
# ## EXAMPLE
#
# ```bash
# ARCH=$(uname_arch)
# ```
#
#
uname_arch() {
  _shlib_arch=$(uname -m)
  case $_shlib_arch in
    x86_64) _shlib_arch="amd64" ;;
    i86pc) _shlib_arch="amd64" ;;
    x86) _shlib_arch="386" ;;
    i686) _shlib_arch="386" ;;
    i386) _shlib_arch="386" ;;
    aarch64) _shlib_arch="arm64" ;;
    armv5*) _shlib_arch="armv5" ;;
    armv6*) _shlib_arch="armv6" ;;
    armv7*) _shlib_arch="armv7" ;;
    loongarch64) _shlib_arch="loong64" ;;
  esac
  echo "${_shlib_arch}"
}
