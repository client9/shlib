# uname_arch converts `uname -m` back into standardized golang
# OS types. 
#
# See also `uname_arch_check` for a self-check
#
# ## NOTES
#
# * ARM CPUs are not added here but should be
#
# ## EXAMPLE
# 
# ```bash
# ARCH=$(uname_arch)
# ```
#
#
uname_arch() {
  arch=$(uname -m)
  case $arch in
    x86_64) arch="amd64" ;;
    x86)    arch="386" ;;
    i686)   arch="386" ;;
    i386)   arch="386" ;;
  esac
  echo ${arch}
}
