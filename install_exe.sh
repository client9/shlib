# install_exe: copy a file into place and make it executable
#
# ## EXAMPLE
#
# ```bash
# install_exe "${tmpdir}/mytool" "${BINDIR}/mytool"
# ```
#
# DEST is the full destination path, not a directory, and its parent must
# already exist.
#
# This exists because install(1) cannot be used portably.  It is not in POSIX,
# and its grammar differs by platform: GNU and BSD accept `install SRC DST`,
# while Solaris and illumos ship the SVR4 version, which does not -- so that
# form fails outright there.  cp and chmod are both POSIX.
#
# DEST is unlinked before copying: overwriting a binary that is currently
# executing fails with ETXTBSY on several systems, which is why install(1)
# unlinks first as well.
#
# DEPENDS:
#   log, echoerr
#
install_exe() {
  _shlib_install_src=$1
  _shlib_install_dst=$2

  if [ -z "$_shlib_install_src" ] || [ -z "$_shlib_install_dst" ]; then
    log_err "install_exe usage: install_exe SOURCE DEST"
    return 1
  fi
  if [ ! -f "$_shlib_install_src" ]; then
    log_err "install_exe source '${_shlib_install_src}' does not exist"
    return 1
  fi

  rm -f "$_shlib_install_dst"
  cp "$_shlib_install_src" "$_shlib_install_dst" || return 1
  chmod 0755 "$_shlib_install_dst" || return 1
}
