# mktmpdir: create a fresh, private temporary directory and echo its path
#
# The caller owns the directory and is responsible for removing it:
#
# ```bash
# tmpdir=$(mktmpdir) || exit 1
# trap 'rm -rf "$tmpdir"' EXIT
# ```
#
# TMPDIR, if set, is used as the *parent*.  An earlier version returned
# $TMPDIR itself whenever it was set -- which is always the case on macOS and
# in most CI -- so every caller shared one predictable directory, two calls in
# a row collided, and the caller's TMPDIR was overwritten as a side effect.
mktmpdir() {
  # strip any trailing slash so the result has no "//"
  _shlib_mktmpdir_parent=${TMPDIR:-/tmp}
  _shlib_mktmpdir_dir=$(mktemp -d "${_shlib_mktmpdir_parent%/}/shlib.XXXXXXXXXX") || return 1

  # Set the mode explicitly rather than inheriting whatever mktemp does.
  # mktemp is not in POSIX and its default is not guaranteed: git-bash on
  # Windows creates 0755.  Failure is not fatal -- on Windows the mode bits
  # are an emulation over NTFS ACLs and the parent temp directory is already
  # per-user -- but on a real POSIX system this is the privacy guarantee.
  chmod 0700 "$_shlib_mktmpdir_dir" 2>/dev/null

  echo "$_shlib_mktmpdir_dir"
}
