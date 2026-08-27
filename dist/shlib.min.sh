cat /dev/null <<EOF
shlib 2026.08.27
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
_logp=6
log_set_priority() {
  _logp="$1"
}
log_priority() {
  if test -z "$1"; then
    echo "$_logp"
    return
  fi
  [ "$1" -le "$_logp" ]
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
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  case "$os" in
    msys*) os="windows" ;;
    mingw*) os="windows" ;;
    cygwin*) os="windows" ;;
  esac
  if [ "$os" = "sunos" ]; then
    if [ "$(uname -o 2>/dev/null)" = "illumos" ]; then
      os="illumos"
    else
      os="solaris"
    fi
  fi
  echo "$os"
}
uname_arch() {
  arch=$(uname -m)
  case $arch in
    x86_64) arch="amd64" ;;
    i86pc) arch="amd64" ;;
    x86) arch="386" ;;
    i686) arch="386" ;;
    i386) arch="386" ;;
    aarch64) arch="arm64" ;;
    armv5*) arch="armv5" ;;
    armv6*) arch="armv6" ;;
    armv7*) arch="armv7" ;;
    loongarch64) arch="loong64" ;;
  esac
  echo "${arch}"
}
uname_os_check() {
  os=$(uname_os)
  case "$os" in
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
  log_crit "uname_os_check '$(uname -s)' got converted to '$os' which is not a GOOS value"
  return 1
}
uname_arch_check() {
  arch=$(uname_arch)
  case "$arch" in
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
  log_crit "uname_arch_check '$(uname -m)' got converted to '$arch' which is not a GOARCH value"
  return 1
}
mktmpdir() {
  _mktmpdir_parent=${TMPDIR:-/tmp}
  mktemp -d "${_mktmpdir_parent%/}/shlib.XXXXXXXXXX"
}
untar() {
  tarball=$1
  case "${tarball}" in
    *.tar.gz | *.tgz) tar -xzf "${tarball}" ;;
    *.tar.bz2 | *.tbz | *.tbz2) tar -xjf "${tarball}" ;;
    *.tar.xz | *.txz) tar -xJf "${tarball}" ;;
    *.tar.zst | *.tzst)
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
http_download_curl() {
  local_file=$1
  source_url=$2
  header=$3
  if [ -z "$header" ]; then
    curl -fsSL -o "$local_file" "$source_url"
  else
    curl -fsSL -H "$header" -o "$local_file" "$source_url"
  fi
}
http_download_wget() {
  local_file=$1
  source_url=$2
  header=$3
  if [ -z "$header" ]; then
    wget -q -O "$local_file" "$source_url"
  else
    wget -q --header "$header" -O "$local_file" "$source_url"
  fi
}
http_download() {
  log_debug "http_download $2"
  if is_command curl; then
    http_download_curl "$@"
    return
  elif is_command wget; then
    http_download_wget "$@"
    return
  fi
  log_crit "http_download unable to find wget or curl"
  return 1
}
http_copy() {
  _http_copy_dir=${TMPDIR:-/tmp}
  tmp=$(mktemp "${_http_copy_dir%/}/shlib.XXXXXXXXXX") || return 1
  if ! http_download "${tmp}" "$1" "$2"; then
    rm -f "${tmp}"
    return 1
  fi
  cat "${tmp}"
  rc=$?
  rm -f "${tmp}"
  return $rc
}
http_last_modified() {
  url=${1:-/dev/stdin}
  curl -L -s --fail --head "$url" | grep -i 'Last-Modified:' | tail -c 31 | head -c 29
}
github_api() {
  local_file=$1
  source_url=$2
  header=""
  case "$source_url" in
    https://api.github.com*)
      test -z "$GITHUB_TOKEN" || header="Authorization: token $GITHUB_TOKEN"
      ;;
  esac
  http_download "$local_file" "$source_url" "$header"
}
github_release() {
  owner_repo=$1
  version=$2
  test -z "$version" && version="latest"
  giturl="https://github.com/${owner_repo}/releases/${version}"
  json=$(http_copy "$giturl" "Accept:application/json")
  test -z "$json" && return 1
  version=$(echo "$json" | tr -s '\n' ' ' | sed 's/.*"tag_name":"//' | sed 's/".*//')
  test -z "$version" && return 1
  echo "$version"
}
hash_md5() {
  if [ -z "$1" ]; then
    set --
  else
    set -- "$1"
  fi
  if is_command md5sum; then
    sum=$(md5sum "$@" 2>/dev/null) || return 1
    echo "$sum" | cut -d ' ' -f 1
  elif is_command md5; then
    md5 -q "$@" 2>/dev/null
  elif is_command openssl; then
    sum=$(openssl dgst -md5 "$@") || return 1
    echo "$sum" | awk '{print $NF}'
  else
    log_crit "hash_md5 unable to find command to compute md5 hash"
    return 1
  fi
}
hash_sha256() {
  if [ -z "$1" ]; then
    set --
  else
    set -- "$1"
  fi
  if is_command gsha256sum; then
    hash=$(gsha256sum "$@") || return 1
    echo "$hash" | cut -d ' ' -f 1
  elif is_command sha256sum; then
    hash=$(sha256sum "$@") || return 1
    echo "$hash" | cut -d ' ' -f 1
  elif is_command shasum; then
    hash=$(shasum -a 256 "$@" 2>/dev/null) || return 1
    echo "$hash" | cut -d ' ' -f 1
  elif is_command openssl; then
    hash=$(openssl dgst -sha256 "$@") || return 1
    echo "$hash" | awk '{print $NF}'
  else
    log_crit "hash_sha256 unable to find command to compute sha-256 hash"
    return 1
  fi
}
hash_sha256_verify() {
  TARGET=$1
  checksums=$2
  if [ -z "$checksums" ]; then
    log_err "hash_sha256_verify checksum file not specified in arg2"
    return 1
  fi
  BASENAME=${TARGET##*/}
  want=$(awk -v name="$BASENAME" '
    {
      f = $2
      sub(/^\*/, "", f)
      sub(/.*\//, "", f)
      if (f == name) print $1
    }' "$checksums" 2>/dev/null)
  if [ -z "$want" ]; then
    log_err "hash_sha256_verify unable to find checksum for '${TARGET}' in '${checksums}'"
    return 1
  fi
  nwant=$(printf '%s\n' "$want" | wc -l | tr -d ' ')
  if [ "$nwant" != "1" ]; then
    log_err "hash_sha256_verify multiple checksums for '${BASENAME}' in '${checksums}'"
    return 1
  fi
  got=$(hash_sha256 "$TARGET")
  if [ "$want" != "$got" ]; then
    log_err "hash_sha256_verify checksum for '$TARGET' did not verify ${want} vs $got"
    return 1
  fi
}
hash_sha512() {
  if [ -z "$1" ]; then
    set --
  else
    set -- "$1"
  fi
  if is_command gsha512sum; then
    hash=$(gsha512sum "$@") || return 1
    echo "$hash" | cut -d ' ' -f 1
  elif is_command sha512sum; then
    hash=$(sha512sum "$@") || return 1
    echo "$hash" | cut -d ' ' -f 1
  elif is_command shasum; then
    hash=$(shasum -a 512 "$@" 2>/dev/null) || return 1
    echo "$hash" | cut -d ' ' -f 1
  elif is_command openssl; then
    hash=$(openssl dgst -sha512 "$@") || return 1
    echo "$hash" | awk '{print $NF}'
  else
    log_crit "hash_sha512 unable to find command to compute sha-512 hash"
    return 1
  fi
}
hash_sha512_verify() {
  TARGET=$1
  checksums=$2
  if [ -z "$checksums" ]; then
    log_err "hash_sha512_verify checksum file not specified in arg2"
    return 1
  fi
  BASENAME=${TARGET##*/}
  want=$(awk -v name="$BASENAME" '
    {
      f = $2
      sub(/^\*/, "", f)
      sub(/.*\//, "", f)
      if (f == name) print $1
    }' "$checksums" 2>/dev/null)
  if [ -z "$want" ]; then
    log_err "hash_sha512_verify unable to find checksum for '${TARGET}' in '${checksums}'"
    return 1
  fi
  nwant=$(printf '%s\n' "$want" | wc -l | tr -d ' ')
  if [ "$nwant" != "1" ]; then
    log_err "hash_sha512_verify multiple checksums for '${BASENAME}' in '${checksums}'"
    return 1
  fi
  got=$(hash_sha512 "$TARGET")
  if [ "$want" != "$got" ]; then
    log_err "hash_sha512_verify checksum for '$TARGET' did not verify ${want} vs $got"
    return 1
  fi
}
date_iso8601() {
  date -u +%Y-%m-%dT%H:%M:%S+0000
}
git_clone_or_update() {
  giturl=$1
  if [ ! -d "$gitrepo" ]; then
    git clone "$giturl"
  else
    (cd "$gitrepo" && git pull >/dev/null)
  fi
}
cat /dev/null <<EOF
------------------------------------------------------------------------
End of functions from https://github.com/client9/shlib
------------------------------------------------------------------------
EOF
