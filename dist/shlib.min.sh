cat /dev/null <<EOF
shlib 2026.08.28
https://github.com/client9/shlib
EOF
cat /dev/null <<EOF
------------------------------------------------------------------------
https://github.com/client9/shlib - portable posix shell functions
Public domain - http://unlicense.org
https://github.com/client9/shlib/blob/master/LICENSE.md
but credit (and pull requests) appreciated.
------------------------------------------------------------------------
EOF
is_command() {
  command -v "$1" >/dev/null
}
echoerr() {
  echo "$@" 1>&2
}
log_prefix() {
  echo "$0"
}
_shlib_logp=6
log_set_priority() {
  _shlib_logp="$1"
}
log_priority() {
  if test -z "${1-}"; then
    echo "$_shlib_logp"
    return
  fi
  [ "$1" -le "$_shlib_logp" ]
}
log_tag() {
  case $1 in
    0) echo "emerg" ;;
    1) echo "alert" ;;
    2) echo "crit" ;;
    3) echo "err" ;;
    4) echo "warning" ;;
    5) echo "notice" ;;
    6) echo "info" ;;
    7) echo "debug" ;;
    *) echo "$1" ;;
  esac
}
log_debug() {
  log_priority 7 || return 0
  echoerr "$(log_prefix)" "$(log_tag 7)" "$@"
}
log_info() {
  log_priority 6 || return 0
  echoerr "$(log_prefix)" "$(log_tag 6)" "$@"
}
log_err() {
  log_priority 3 || return 0
  echoerr "$(log_prefix)" "$(log_tag 3)" "$@"
}
log_crit() {
  log_priority 2 || return 0
  echoerr "$(log_prefix)" "$(log_tag 2)" "$@"
}
uname_os() {
  _shlib_os=$(uname -s | tr '[:upper:]' '[:lower:]')
  case "$_shlib_os" in
    msys*) _shlib_os="windows" ;;
    mingw*) _shlib_os="windows" ;;
    cygwin*) _shlib_os="windows" ;;
    win*) _shlib_os="windows" ;; # for windows busybox and like # https://frippery.org/busybox/
  esac
  if [ "$_shlib_os" = "sunos" ]; then
    if [ "$(uname -o 2>/dev/null)" = "illumos" ]; then
      _shlib_os="illumos"
    else
      _shlib_os="solaris"
    fi
  fi
  echo "$_shlib_os"
}
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
uname_os_check() {
  _shlib_os=$(uname_os)
  case "$_shlib_os" in
    aix) return 0 ;;
    darwin) return 0 ;;
    dragonfly) return 0 ;;
    freebsd) return 0 ;;
    linux) return 0 ;;
    android) return 0 ;;
    midnightbsd) return 0 ;;
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
    amd64p32) return 0 ;;
  esac
  log_crit "uname_arch_check '$(uname -m)' got converted to '$_shlib_arch' which is not a recognized architecture name"
  return 1
}
mktmpdir() {
  _shlib_mktmpdir_parent=${TMPDIR:-/tmp}
  _shlib_mktmpdir_dir=$(mktemp -d "${_shlib_mktmpdir_parent%/}/shlib.XXXXXXXXXX") || return 1
  chmod 0700 "$_shlib_mktmpdir_dir" 2>/dev/null
  echo "$_shlib_mktmpdir_dir"
}
untar() {
  _shlib_tarball=$1
  case "${_shlib_tarball}" in
    *.tar.gz | *.tgz) tar -xzf "${_shlib_tarball}" ;;
    *.tar.bz2 | *.tbz | *.tbz2) tar -xjf "${_shlib_tarball}" ;;
    *.tar.xz | *.txz) tar -xJf "${_shlib_tarball}" ;;
    *.tar.zst | *.tzst)
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
http_download_curl() {
  _shlib_local_file=$1
  _shlib_source_url=$2
  _shlib_header=${3-}
  if [ -z "$_shlib_header" ]; then
    curl -fsSL -o "$_shlib_local_file" "$_shlib_source_url"
  else
    curl -fsSL -H "$_shlib_header" -o "$_shlib_local_file" "$_shlib_source_url"
  fi
}
http_download_wget() {
  _shlib_local_file=$1
  _shlib_source_url=$2
  _shlib_header=${3-}
  if [ -z "$_shlib_header" ]; then
    wget -q -O "$_shlib_local_file" "$_shlib_source_url"
  else
    wget -q --header "$_shlib_header" -O "$_shlib_local_file" "$_shlib_source_url"
  fi
}
http_download_fetch() {
  _shlib_local_file=$1
  _shlib_source_url=$2
  _shlib_header=${3-}
  if [ -z "$_shlib_header" ]; then
    fetch -q -o "$_shlib_local_file" "$_shlib_source_url"
    return
  fi
  case "$_shlib_header" in
    [Aa]ccept:*)
      _shlib_accept=${_shlib_header#*:}
      _shlib_accept=${_shlib_accept# }
      HTTP_ACCEPT="$_shlib_accept" fetch -q -o "$_shlib_local_file" "$_shlib_source_url"
      return
      ;;
  esac
  log_crit "http_download fetch cannot send '${_shlib_header%%:*}' headers; install curl or wget"
  return 1
}
http_download_ftp() {
  _shlib_local_file=$1
  _shlib_source_url=$2
  _shlib_header=${3-}
  if [ -z "$_shlib_header" ]; then
    ftp -V -o "$_shlib_local_file" "$_shlib_source_url"
    return
  fi
  case "$_shlib_header" in
    [Aa]ccept:*)
      log_crit "http_download ftp cannot override the Accept header; install curl or wget"
      return 1
      ;;
  esac
  if ftp -Z </dev/null 2>&1 | grep '\[-H ' >/dev/null 2>&1; then
    ftp -V -H "$_shlib_header" -o "$_shlib_local_file" "$_shlib_source_url"
    return
  fi
  log_crit "http_download ftp cannot send '${_shlib_header%%:*}' headers; install curl or wget"
  return 1
}
http_download() {
  log_debug "http_download $2"
  if is_command curl; then
    http_download_curl "$@"
    return
  elif is_command wget; then
    http_download_wget "$@"
    return
  elif is_command fetch; then
    http_download_fetch "$@"
    return
  elif is_command ftp; then
    http_download_ftp "$@"
    return
  fi
  log_crit "http_download unable to find curl, wget, fetch or ftp"
  return 1
}
http_copy() {
  _shlib_http_copy_dir=${TMPDIR:-/tmp}
  _shlib_tmp=$(mktemp "${_shlib_http_copy_dir%/}/shlib.XXXXXXXXXX") || return 1
  if ! http_download "${_shlib_tmp}" "$1" "${2-}"; then
    rm -f "${_shlib_tmp}"
    return 1
  fi
  cat "${_shlib_tmp}"
  _shlib_rc=$?
  rm -f "${_shlib_tmp}"
  return $_shlib_rc
}
http_last_modified() {
  _shlib_url=${1:-/dev/stdin}
  curl -L -s --fail --head "$_shlib_url" | grep -i 'Last-Modified:' | tail -c 31 | head -c 29
}
github_api() {
  _shlib_local_file=$1
  _shlib_source_url=$2
  _shlib_header=""
  case "$_shlib_source_url" in
    https://api.github.com*)
      test -z "${GITHUB_TOKEN-}" || _shlib_header="Authorization: token $GITHUB_TOKEN"
      ;;
  esac
  http_download "$_shlib_local_file" "$_shlib_source_url" "$_shlib_header"
}
github_release() {
  _shlib_owner_repo=$1
  _shlib_version=${2-}
  test -z "$_shlib_version" && _shlib_version="latest"
  _shlib_giturl="https://github.com/${_shlib_owner_repo}/releases/${_shlib_version}"
  _shlib_json=$(http_copy "$_shlib_giturl" "Accept:application/json")
  test -z "$_shlib_json" && return 1
  _shlib_flat=$(echo "$_shlib_json" | tr -s '\n' ' ')
  _shlib_version=$(printf '%s\n' "$_shlib_flat" | sed 's/.*"tag_name":"//' | sed 's/".*//')
  test -z "$_shlib_version" && return 1
  case "$_shlib_version" in
    *[!A-Za-z0-9._+-]* | "")
      log_err "github_release did not find a tag at ${_shlib_giturl} (got '$(echo "$_shlib_version" | cut -c1-40)')"
      return 1
      ;;
  esac
  echo "$_shlib_version"
}
hash_md5() {
  if [ -z "${1-}" ]; then
    set --
  else
    set -- "$1"
  fi
  if is_command md5sum; then
    _shlib_sum=$(md5sum "$@" 2>/dev/null) || return 1
    echo "$_shlib_sum" | cut -d ' ' -f 1
  elif is_command md5; then
    md5 -q "$@" 2>/dev/null
  elif is_command openssl; then
    _shlib_sum=$(openssl dgst -md5 "$@") || return 1
    echo "$_shlib_sum" | awk '{print $NF}'
  else
    log_crit "hash_md5 unable to find command to compute md5 hash"
    return 1
  fi
}
hash_sha256() {
  if [ -z "${1-}" ]; then
    set --
  else
    set -- "$1"
  fi
  if is_command gsha256sum; then
    _shlib_hash=$(gsha256sum "$@") || return 1
    echo "$_shlib_hash" | cut -d ' ' -f 1
  elif is_command sha256sum; then
    _shlib_hash=$(sha256sum "$@") || return 1
    echo "$_shlib_hash" | cut -d ' ' -f 1
  elif is_command shasum; then
    _shlib_hash=$(shasum -a 256 "$@" 2>/dev/null) || return 1
    echo "$_shlib_hash" | cut -d ' ' -f 1
  elif is_command openssl; then
    _shlib_hash=$(openssl dgst -sha256 "$@") || return 1
    echo "$_shlib_hash" | awk '{print $NF}'
  else
    log_crit "hash_sha256 unable to find command to compute sha-256 hash"
    return 1
  fi
}
hash_sha256_verify() {
  _shlib_target=$1
  _shlib_checksums=${2-}
  if [ -z "$_shlib_checksums" ]; then
    log_err "hash_sha256_verify checksum file not specified in arg2"
    return 1
  fi
  _shlib_basename=${_shlib_target##*/}
  _shlib_want=$(awk -v name="$_shlib_basename" '
    {
      f = $2
      sub(/^\*/, "", f)
      sub(/.*\//, "", f)
      if (f == name) print $1
    }' "$_shlib_checksums" 2>/dev/null)
  if [ -z "$_shlib_want" ]; then
    log_err "hash_sha256_verify unable to find checksum for '${_shlib_target}' in '${_shlib_checksums}'"
    return 1
  fi
  _shlib_nwant=$(printf '%s\n' "$_shlib_want" | wc -l | tr -d ' ')
  if [ "$_shlib_nwant" != "1" ]; then
    log_err "hash_sha256_verify multiple checksums for '${_shlib_basename}' in '${_shlib_checksums}'"
    return 1
  fi
  _shlib_got=$(hash_sha256 "$_shlib_target")
  if [ "$_shlib_want" != "$_shlib_got" ]; then
    log_err "hash_sha256_verify checksum for '$_shlib_target' did not verify ${_shlib_want} vs $_shlib_got"
    return 1
  fi
}
hash_sha512() {
  if [ -z "${1-}" ]; then
    set --
  else
    set -- "$1"
  fi
  if is_command gsha512sum; then
    _shlib_hash=$(gsha512sum "$@") || return 1
    echo "$_shlib_hash" | cut -d ' ' -f 1
  elif is_command sha512sum; then
    _shlib_hash=$(sha512sum "$@") || return 1
    echo "$_shlib_hash" | cut -d ' ' -f 1
  elif is_command shasum; then
    _shlib_hash=$(shasum -a 512 "$@" 2>/dev/null) || return 1
    echo "$_shlib_hash" | cut -d ' ' -f 1
  elif is_command openssl; then
    _shlib_hash=$(openssl dgst -sha512 "$@") || return 1
    echo "$_shlib_hash" | awk '{print $NF}'
  else
    log_crit "hash_sha512 unable to find command to compute sha-512 hash"
    return 1
  fi
}
hash_sha512_verify() {
  _shlib_target=$1
  _shlib_checksums=${2-}
  if [ -z "$_shlib_checksums" ]; then
    log_err "hash_sha512_verify checksum file not specified in arg2"
    return 1
  fi
  _shlib_basename=${_shlib_target##*/}
  _shlib_want=$(awk -v name="$_shlib_basename" '
    {
      f = $2
      sub(/^\*/, "", f)
      sub(/.*\//, "", f)
      if (f == name) print $1
    }' "$_shlib_checksums" 2>/dev/null)
  if [ -z "$_shlib_want" ]; then
    log_err "hash_sha512_verify unable to find checksum for '${_shlib_target}' in '${_shlib_checksums}'"
    return 1
  fi
  _shlib_nwant=$(printf '%s\n' "$_shlib_want" | wc -l | tr -d ' ')
  if [ "$_shlib_nwant" != "1" ]; then
    log_err "hash_sha512_verify multiple checksums for '${_shlib_basename}' in '${_shlib_checksums}'"
    return 1
  fi
  _shlib_got=$(hash_sha512 "$_shlib_target")
  if [ "$_shlib_want" != "$_shlib_got" ]; then
    log_err "hash_sha512_verify checksum for '$_shlib_target' did not verify ${_shlib_want} vs $_shlib_got"
    return 1
  fi
}
date_iso8601() {
  date -u +%Y-%m-%dT%H:%M:%S+0000
}
git_clone_or_update() {
  _shlib_giturl=$1
  _shlib_gitrepo=${_shlib_giturl##*/}   # foo.git
  _shlib_gitrepo=${_shlib_gitrepo%.git} # foo
  if [ ! -d "$_shlib_gitrepo" ]; then
    git clone "$_shlib_giturl"
  else
    (cd "$_shlib_gitrepo" && git pull >/dev/null)
  fi
}
cat /dev/null <<EOF
------------------------------------------------------------------------
End of functions from https://github.com/client9/shlib
------------------------------------------------------------------------
EOF
