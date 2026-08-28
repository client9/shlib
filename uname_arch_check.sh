# uname_arch_check: self-check that uname_arch produced a recognized architecture name
#
# A check on the mapping, not on compatibility with any one toolchain.
# The set matches Go's GOARCH names, which is where the convention
# came from, except that ARM is spelled `armv5`, `armv6`, `armv7`
# rather than Go's `arm` plus a separate `GOARM`.
#
# Go's own list, for reference, is around here:
# https://github.com/golang/go/blob/master/src/cmd/dist/build.go#L1094
# or `go tool dist list`
#
uname_arch_check() {
  _shlib_arch=$(uname_arch)
  case "$_shlib_arch" in
    386) return 0 ;;
    amd64) return 0 ;;
    arm64) return 0 ;;
    armv5) return 0 ;;
    armv6) return 0 ;;
    armv7) return 0 ;;
    ppc64) return 0 ;;
    ppc64le) return 0 ;;
    mips) return 0 ;;
    mipsle) return 0 ;;
    mips64) return 0 ;;
    mips64le) return 0 ;;
    s390x) return 0 ;;
    riscv64) return 0 ;;
    loong64) return 0 ;;
    # amd64p32 was dropped from Go in 1.14 along with nacl; kept so that
    # existing callers do not start failing.
    amd64p32) return 0 ;;
  esac
  log_crit "uname_arch_check '$(uname -m)' got converted to '$_shlib_arch' which is not a recognized architecture name"
  return 1
}
