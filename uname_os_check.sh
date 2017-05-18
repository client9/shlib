# uname_os_check: self-check `uname_os`
# 
# This checks that uname_os is working correctly.  If
# the conversion from `uname -s` to golang GOOS isn't
# done correctly it will error.
# 
uname_os_check() {
  os=$(uname_os)
  case "$os" in
   darwin)    return 0 ;;
   dragonfly) return 0 ;;
   freebsd)   return 0 ;;
   linux)     return 0 ;;
   android)   return 0 ;;
   nacl)      return 0 ;;
   netbsd)    return 0 ;;
   openbsd)   return 0 ;;
   plan9)     return 0 ;;
   solaris)   return 0 ;;
   windows)   return 0 ;;
  esac
  echo "$0: uname_os_check: internal error '$(uname -s)' got coverted to '$os' which is not a GOOS value. Please file bug at https://github.com/client9/posixshell"
  return 1
}
