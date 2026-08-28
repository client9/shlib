# uname_os_check: self-check that uname_os produced a recognized OS name
#
# This checks that uname_os is working correctly: if the conversion
# from `uname -s` to a canonical name is not done correctly it errors.
# It is a check on the mapping, not on compatibility with any one
# toolchain.
#
# A name is recognized when a real system's `uname -s` maps to it AND
# it is the spelling projects use when naming release artifacts for
# that platform.  Names are not admitted because Go added them, nor
# dropped because Go removed them; that is why this list is not
# identical to `go tool dist list`.
#
uname_os_check() {
  _shlib_os=$(uname_os)
  case "$_shlib_os" in
    aix) return 0 ;;
    darwin) return 0 ;;
    dragonfly) return 0 ;;
    freebsd) return 0 ;;
    linux) return 0 ;;
    android) return 0 ;;
    # never a GOOS; MidnightBSD reports it and names artifacts for it (PR #33)
    midnightbsd) return 0 ;;
    # nacl was dropped from Go in 1.14; kept so that existing callers do
    # not start failing.
    nacl) return 0 ;;
    netbsd) return 0 ;;
    openbsd) return 0 ;;
    plan9) return 0 ;;
    solaris) return 0 ;;
    illumos) return 0 ;;
    ios) return 0 ;;
    js) return 0 ;;
    wasip1) return 0 ;;
    windows) return 0 ;;
  esac
  log_crit "uname_os_check '$(uname -s)' got converted to '$_shlib_os' which is not a recognized OS name"
  return 1
}
