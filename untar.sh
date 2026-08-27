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
  tarball=$1
  case "${tarball}" in
    *.tar.gz | *.tgz) tar -xzf "${tarball}" ;;
    *.tar.bz2 | *.tbz | *.tbz2) tar -xjf "${tarball}" ;;
    *.tar.xz | *.txz) tar -xJf "${tarball}" ;;
    *.tar.zst | *.tzst)
      # busybox tar has no --zstd, so decompress explicitly.  Check for the
      # tool up front: the exit status of a pipeline is that of its last
      # command, so a missing zstd would otherwise be reported by tar.
      if ! is_command zstd; then
        log_err "untar zstd is required to unpack ${tarball}"
        return 1
      fi
      zstd -dc "${tarball}" | tar -xf -
      ;;
    *.tar) tar -xf "${tarball}" ;;
    *.zip)
      if ! is_command unzip; then
        log_err "untar unzip is required to unpack ${tarball}"
        return 1
      fi
      unzip "${tarball}"
      ;;
    *)
      log_err "untar unknown archive format for ${tarball}"
      return 1
      ;;
  esac
}
