# 
# supported names can be found
# around here: https://github.com/golang/go/blob/master/src/cmd/dist/build.go#L1094
# or by running `go tool dist list`
#
uname_arch_check() {
  arch=$(uname_arch)
  case "$arch" in
   386)      return 0 ;;
   amd64)    return 0 ;;
   arm64)    return 0 ;;
   arm)      return 0 ;;
   ppc64)    return 0 ;;
   ppc64le)  return 0 ;;
   mips)     return 0 ;;
   mipsle)   return 0 ;;
   mips64)   return 0 ;;
   mips64le) return 0 ;;
   s390x)    return 0 ;;
   amd64p32) return 0 ;;
  esac
  echo "$0: uname_arch_check: internal error '$(uname -m)' got coverted to '$arch' which is not a GOARCH value.  Please file bug report at https://github.com/client9/posixshell"
  return 1
}
