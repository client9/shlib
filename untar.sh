#
# untar: unpack $1 into the current directory
#
# if you need to unpack in specific directory use a
# subshell and cd
#
# (cd /foo && untar mytarball.gz)
#
# DEPENDS:
#   log, is_command
#
untar() {
  _shlib_tarball=$1
  case "${_shlib_tarball}" in
    *.tar.gz | *.tgz) tar -xzf "${_shlib_tarball}" ;;
    *.tar.bz2 | *.tbz | *.tbz2) tar -xjf "${_shlib_tarball}" ;;
    *.tar.xz | *.txz) tar -xJf "${_shlib_tarball}" ;;
    *.tar.zst | *.tzst)
      # busybox tar has no --zstd, so decompress explicitly.  Check for the
      # tool up front: the exit status of a pipeline is that of its last
      # command, so a missing zstd would otherwise be reported by tar.
      if ! is_command zstd; then
        log_err "untar zstd is required to unpack ${_shlib_tarball}"
        return 1
      fi
      zstd -dc "${_shlib_tarball}" | tar -xf -
      ;;
    *.tar) tar -xf "${_shlib_tarball}" ;;
    *.zip)
      if ! is_command unzip; then
        log_err "untar unzip is required to unpack ${_shlib_tarball}"
        return 1
      fi
      unzip "${_shlib_tarball}"
      ;;
    *)
      log_err "untar unknown archive format for ${_shlib_tarball}"
      return 1
      ;;
  esac
}
