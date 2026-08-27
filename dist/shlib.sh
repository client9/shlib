cat /dev/null <<EOF
shlib 2026.08.27
https://github.com/client9/shlib
EOF
#!/bin/sh
cat /dev/null <<EOF
------------------------------------------------------------------------
https://github.com/client9/shlib - portable posix shell functions

Public domain - http://unlicense.org
https://github.com/client9/shlib/blob/master/LICENSE.md

but credit (and pull requests) appreciated.
------------------------------------------------------------------------
EOF
#
# is_command: returns true if command exists
#
# `which` is not portable, in particular is often
# not available on RedHat/CentOS systems.
#
# `type` is implemented in many shells but technically not
# part of the posix spec.
#
# `command -v`
#
is_command() {
  command -v "$1" >/dev/null
  #type "$1" > /dev/null 2> /dev/null
}
# write message to stderr
echoerr() {
  echo "$@" 1>&2
}
# function to prefix each log output
#  over-ride to add custom output or format
#
# by default prints the script name ($0)
log_prefix() {
  echo "$0"
}

# default priority
_logp=6

# set the log priority
#  todo: fancy turn string into number
log_set_priority() {
  _logp="$1"
}

# if no args, return the priority
# if arg, then test if greater than or equals to priority
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

# log_crit is for platform problems
log_crit() {
  log_priority 2 || return 0
  echoerr "$(log_prefix)" "$(log_tag 2)" "$@"
}
#!/bin/sh

# uname_os converts `uname -s` into standard golang OS types
# golang types are used since they cover
# most platforms and are standardized while raw uname values vary
# wildly.  See complete list of values by running
# "go tool dist list"
#
# ## EXAMPLE
#
# ```bash
# OS=$(uname_os)
# ```
#
uname_os() {
  os=$(uname -s | tr '[:upper:]' '[:lower:]')

  # fixed up for https://github.com/client9/shlib/issues/3
  case "$os" in
    msys*) os="windows" ;;
    mingw*) os="windows" ;;
    cygwin*) os="windows" ;;
    win*) os="windows" ;; # for windows busybox and like # https://frippery.org/busybox/
  esac

  # Sun Solaris and derived OS (Illumos, Oracle Solaris) reports to be the very ancient SunOS via uname not what it actually is
  if [ "$os" = "sunos" ]; then
    # Current illumos versions have -o to check if they are illumos or Solaris without breaking most builds.
    if [ "$(uname -o 2>/dev/null)" = "illumos" ]; then
      os="illumos"
    else
      os="solaris"
    fi
  fi

  # other fixups here
  echo "$os"
}
# uname_arch converts `uname -m` back into standardized golang
# OS types.
#
# See also `uname_arch_check` for a self-check
#
# ## NOTES
#
# Notes on ARM:
# arm 5,6,7: uname is of form `armv6l`, ` armv7l` where a letter
# or something else is after the number. Has examples:
# https://github.com/golang/go/wiki/GoArm
# https://en.wikipedia.org/wiki/List_of_ARM_microarchitectures
#
# arm8 is known as arm64 and aarch64
#
# more notes: https://github.com/golang/go/issues/13669
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
# uname_os_check: self-check `uname_os`
#
# This checks that uname_os is working correctly.  If
# the conversion from `uname -s` to golang GOOS isn't
# done correctly it will error.
#
uname_os_check() {
  os=$(uname_os)
  case "$os" in
    aix) return 0 ;;
    darwin) return 0 ;;
    dragonfly) return 0 ;;
    freebsd) return 0 ;;
    linux) return 0 ;;
    android) return 0 ;;
    # midnightbsd is not a GOOS; accepted for MidnightBSD downstream (PR #33)
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
  log_crit "uname_os_check '$(uname -s)' got converted to '$os' which is not a GOOS value"
  return 1
}
#
# supported names can be found
# around here: https://github.com/golang/go/blob/master/src/cmd/dist/build.go#L1094
# or by running `go tool dist list`
# Except instead of `arm`, this checks for `armv5`, `armv6`, armv7`
#
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
    # amd64p32 was dropped from Go in 1.14 along with nacl; kept so that
    # existing callers do not start failing.
    amd64p32) return 0 ;;
  esac
  log_crit "uname_arch_check '$(uname -m)' got converted to '$arch' which is not a GOARCH value"
  return 1
}
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
  _mktmpdir_parent=${TMPDIR:-/tmp}
  mktemp -d "${_mktmpdir_parent%/}/shlib.XXXXXXXXXX"
}
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
# http_download_curl
#
# on error: displays a message on STDERR and returns non-zero code
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

# http_download_wget
#
# unable to get server response code in a portable manner
# busybox wget (used on alpine linux) does not support "--server-response"
#
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
#
# http_download [local-file] [url] [optional extra header]
#
# if arg3 is not empty it will add it as an extra HTTP header
# must be in the form "foo: bar"
#
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

# http_copy - copies contents of a URL to stdout, or fails
#
# needed since curl is broken
#
# The body is streamed with `cat` rather than captured into a variable:
# command substitution strips trailing newlines and cannot carry NUL, so
# `body=$(cat "$tmp")` silently corrupted binary and newline-terminated data.
# The temp file is removed on the failure path too, which it previously was not.
http_copy() {
  # explicit template: bare `mktemp` ignores TMPDIR on BSD/macOS, so the
  # temp file would land somewhere the caller cannot predict or clean up
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
# returns the last modified timestamp from a HTTP URL
# reads URL from arg 1 or stdin
#
# Requires: curl
#
http_last_modified() {
  url=${1:-/dev/stdin}
  # tail -c 31 -- include ending \r\n
  # head -c 29 -- removes them
  # curl -L = follow redirect
  # curl -s = no progress meter
  curl -L -s --fail --head "$url" | grep -i 'Last-Modified:' | tail -c 31 | head -c 29
}
#!/bin/sh

# github_api: make a api request to api.github.com with auth token
#
# Requires `http_download`
#
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
#!/bin/sh

# github_release: validates tag exists or returns latest tagged release
#
# If tag exists it is returned
# If tag is latest, the latest tag is returned
#
# Requires: http_download, is_command
#
# hack to extract version from output is based on
#
# https://github.com/golang/dep/blob/master/install.sh
#
#  1. tr -s '\n' ' ' --> make sure output is exactly one line
#  2. sed 's/.*"tag_name":"//'  --> remove everything before
#  3. sed 's/".*//' --> remove everything after
#
#  what remains is the version number
#
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
#
# hash_md5: produce md5 hash in hex digits for file or stding
#
# DEPENDS:
#   log, is_command
#
# NB: do not pass /dev/stdin as a filename when reading stdin.  ksh93
# implements pipelines with socketpairs rather than pipes, and a socket
# cannot be reopened by path (open() returns ENXIO on Linux).  Calling the
# hasher with no file operand lets it read fd 0 directly, which is portable.
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
    # "MD5(name)= <hash>" / "(stdin)= <hash>"; digest is the last field
    sum=$(openssl dgst -md5 "$@") || return 1
    echo "$sum" | awk '{print $NF}'
  else
    log_crit "hash_md5 unable to find command to compute md5 hash"
    return 1
  fi
}
# hash_sha256: compute SHA256 of $1 or stdin
#
# ## Example
#
# ```bash
# $ hash_sha256 foobar.tar.gz
# 237982738471928379137
# ```
#
# note lack of pipes to make sure errors are
# caught regardless of shell settings
# sha256sum NOFILE | cut ...
# won't fail unless setpipefail is on
#
# NB: do not pass /dev/stdin as a filename when reading stdin.  ksh93
# implements pipelines with socketpairs rather than pipes, and a socket
# cannot be reopened by path (open() returns ENXIO on Linux).  Calling the
# hasher with no file operand lets it read fd 0 directly, which is portable.
hash_sha256() {
  if [ -z "$1" ]; then
    set --
  else
    set -- "$1"
  fi
  if is_command gsha256sum; then
    # mac homebrew, others
    hash=$(gsha256sum "$@") || return 1
    echo "$hash" | cut -d ' ' -f 1
  elif is_command sha256sum; then
    # gnu, busybox
    hash=$(sha256sum "$@") || return 1
    echo "$hash" | cut -d ' ' -f 1
  elif is_command shasum; then
    # darwin, freebsd?
    hash=$(shasum -a 256 "$@" 2>/dev/null) || return 1
    echo "$hash" | cut -d ' ' -f 1
  elif is_command openssl; then
    # openssl prints "SHA2-256(name)= <hash>" (openssl 3.x),
    # "SHA256(name)= <hash>" (1.x), or "(stdin)= <hash>" when reading stdin.
    # The digest is always the last field.
    hash=$(openssl dgst -sha256 "$@") || return 1
    echo "$hash" | awk '{print $NF}'
  else
    log_crit "hash_sha256 unable to find command to compute sha-256 hash"
    return 1
  fi
}

# hash_sha256_verify validates a binary against a checksum.txt file
#
#
hash_sha256_verify() {
  TARGET=$1
  checksums=$2

  if [ -z "$checksums" ]; then
    log_err "hash_sha256_verify checksum file not specified in arg2"
    return 1
  fi

  # http://stackoverflow.com/questions/2664740/extract-file-basename-without-path-and-extension-in-bash
  BASENAME=${TARGET##*/}

  # Match the filename field EXACTLY.  A plain `grep "$BASENAME" file` matches
  # anywhere on the line and treats the name as a regular expression, so a
  # checksum listed for "evil-foo.tgz" would happily verify "foo.tgz".
  #
  # Handles the usual coreutils/BSD spellings:
  #   <hash>  <name>     two spaces (text mode)
  #   <hash> *<name>     leading asterisk (binary mode)
  #   <hash>  ./<name>   leading ./ or any other directory prefix
  #
  # Filenames containing spaces are not supported; checksum tools escape
  # those and no release artifact we have seen uses them.
  want=$(awk -v name="$BASENAME" '
    {
      f = $2
      sub(/^\*/, "", f)
      sub(/.*\//, "", f)
      if (f == name) print $1
    }' "$checksums" 2>/dev/null)

  # if the file is not listed, $want will be empty
  if [ -z "$want" ]; then
    log_err "hash_sha256_verify unable to find checksum for '${TARGET}' in '${checksums}'"
    return 1
  fi

  # more than one entry for the same name means the checksum file is
  # ambiguous.  Refuse rather than silently picking one.
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
# hash_sha512: compute SHA512 of $1 or stdin
#
# ## Example
#
# ```bash
# $ hash_sha512 foobar.tar.gz
# 237982738471928379137
# ```
#
# note lack of pipes to make sure errors are
# caught regardless of shell settings
# sha512sum NOFILE | cut ...
# won't fail unless setpipefail is on
#
# NB: do not pass /dev/stdin as a filename when reading stdin.  ksh93
# implements pipelines with socketpairs rather than pipes, and a socket
# cannot be reopened by path (open() returns ENXIO on Linux).  Calling the
# hasher with no file operand lets it read fd 0 directly, which is portable.
hash_sha512() {
  if [ -z "$1" ]; then
    set --
  else
    set -- "$1"
  fi
  if is_command gsha512sum; then
    # mac homebrew, others
    hash=$(gsha512sum "$@") || return 1
    echo "$hash" | cut -d ' ' -f 1
  elif is_command sha512sum; then
    # gnu, busybox
    hash=$(sha512sum "$@") || return 1
    echo "$hash" | cut -d ' ' -f 1
  elif is_command shasum; then
    # darwin, freebsd?
    hash=$(shasum -a 512 "$@" 2>/dev/null) || return 1
    echo "$hash" | cut -d ' ' -f 1
  elif is_command openssl; then
    # openssl prints "SHA2-512(name)= <hash>" (openssl 3.x),
    # "SHA512(name)= <hash>" (1.x), or "(stdin)= <hash>" when reading stdin.
    # The digest is always the last field.
    hash=$(openssl dgst -sha512 "$@") || return 1
    echo "$hash" | awk '{print $NF}'
  else
    log_crit "hash_sha512 unable to find command to compute sha-512 hash"
    return 1
  fi
}

# hash_sha512_verify validates a binary against a checksum.txt file
#
#
hash_sha512_verify() {
  TARGET=$1
  checksums=$2

  if [ -z "$checksums" ]; then
    log_err "hash_sha512_verify checksum file not specified in arg2"
    return 1
  fi

  # http://stackoverflow.com/questions/2664740/extract-file-basename-without-path-and-extension-in-bash
  BASENAME=${TARGET##*/}

  # Match the filename field EXACTLY.  A plain `grep "$BASENAME" file` matches
  # anywhere on the line and treats the name as a regular expression, so a
  # checksum listed for "evil-foo.tgz" would happily verify "foo.tgz".
  #
  # Handles the usual coreutils/BSD spellings:
  #   <hash>  <name>     two spaces (text mode)
  #   <hash> *<name>     leading asterisk (binary mode)
  #   <hash>  ./<name>   leading ./ or any other directory prefix
  #
  # Filenames containing spaces are not supported; checksum tools escape
  # those and no release artifact we have seen uses them.
  want=$(awk -v name="$BASENAME" '
    {
      f = $2
      sub(/^\*/, "", f)
      sub(/.*\//, "", f)
      if (f == name) print $1
    }' "$checksums" 2>/dev/null)

  # if the file is not listed, $want will be empty
  if [ -z "$want" ]; then
    log_err "hash_sha512_verify unable to find checksum for '${TARGET}' in '${checksums}'"
    return 1
  fi

  # more than one entry for the same name means the checksum file is
  # ambiguous.  Refuse rather than silently picking one.
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
# date_iso8601 returns a ISO 8601 UTC formatted date
#
# https://en.wikipedia.org/wiki/ISO_8601
#
date_iso8601() {
  date -u +%Y-%m-%dT%H:%M:%S+0000
}
#
# git_clone_or_update: clone a repo, or update it if it exists locally
#
# Given $1 a Git repostory, this with either clone
# or update depending if it exists or not locally.
#
git_clone_or_update() {
  giturl=$1
  gitrepo=${giturl##*/}   # foo.git
  gitrepo=${gitrepo%.git} # foo
  if [ ! -d "$gitrepo" ]; then
    git clone "$giturl"
  else
    (cd "$gitrepo" && git pull >/dev/null)
  fi
}
#!/bin/sh
cat /dev/null <<EOF
------------------------------------------------------------------------
End of functions from https://github.com/client9/shlib
------------------------------------------------------------------------
EOF
