cat /dev/null <<EOF
shlib 2026.08.28
https://github.com/client9/shlib
EOF
#!/bin/sh
cat /dev/null <<EOF
------------------------------------------------------------------------
https://github.com/client9/shlib - portable shell functions for install scripts

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
_shlib_logp=6

# set the log priority
#  todo: fancy turn string into number
log_set_priority() {
  _shlib_logp="$1"
}

# if no args, return the priority
# if arg, then test if greater than or equals to priority
log_priority() {
  if test -z "${1-}"; then
    echo "$_shlib_logp"
    return
  fi
  [ "$1" -le "$_shlib_logp" ]
}

# log_tag: map a syslog priority number to its name
#
# Unrecognised values are echoed back unchanged.
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

# log_debug: log at debug priority (7)
log_debug() {
  log_priority 7 || return 0
  echoerr "$(log_prefix)" "$(log_tag 7)" "$@"
}

# log_info: log at info priority (6)
log_info() {
  log_priority 6 || return 0
  echoerr "$(log_prefix)" "$(log_tag 6)" "$@"
}

# log_err: log at error priority (3)
log_err() {
  log_priority 3 || return 0
  echoerr "$(log_prefix)" "$(log_tag 3)" "$@"
}

# log_crit: log at critical priority (2), for platform problems
log_crit() {
  log_priority 2 || return 0
  echoerr "$(log_prefix)" "$(log_tag 2)" "$@"
}
#!/bin/sh

# uname_os: convert `uname -s` into shlib's canonical OS name
#
# Raw `uname -s` values vary wildly; the canonical names are the ones
# release artifacts are almost always named after.  The set is the one
# Go uses for GOOS -- that is where the convention came from, and
# staying compatible with it is worth doing -- but it is shlib's set,
# and it deviates where reality does.  See `uname_os_check` for the
# full list and the rule for adding to it.
#
# ## EXAMPLE
#
# ```bash
# OS=$(uname_os)
# ```
#
uname_os() {
  _shlib_os=$(uname -s | tr '[:upper:]' '[:lower:]')

  # fixed up for https://github.com/client9/shlib/issues/3
  case "$_shlib_os" in
    msys*) _shlib_os="windows" ;;
    mingw*) _shlib_os="windows" ;;
    cygwin*) _shlib_os="windows" ;;
    win*) _shlib_os="windows" ;; # for windows busybox and like # https://frippery.org/busybox/
  esac

  # Sun Solaris and derived OS (Illumos, Oracle Solaris) reports to be the very ancient SunOS via uname not what it actually is
  if [ "$_shlib_os" = "sunos" ]; then
    # Current illumos versions have -o to check if they are illumos or Solaris without breaking most builds.
    if [ "$(uname -o 2>/dev/null)" = "illumos" ]; then
      _shlib_os="illumos"
    else
      _shlib_os="solaris"
    fi
  fi

  # other fixups here
  echo "$_shlib_os"
}
# uname_arch: convert `uname -m` into shlib's canonical architecture name
#
# The canonical names are the ones release artifacts are almost always
# named after (`amd64`, `arm64`), not the raw `uname -m` string.  The
# set is the one Go uses for GOARCH -- that is where the convention
# came from -- but it is shlib's set; notably ARM is spelled out by
# version rather than folded into `arm` the way Go does.
#
# A project whose assets use the raw kernel spellings (`x86_64`,
# `aarch64`) maps back with the installer's `adjust_arch` hook.
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
# uname_os_check: self-check that uname_os produced a recognized OS name
#
# This checks that uname_os is working correctly: if the conversion
# from `uname -s` to a canonical name is not done correctly it errors.
# It is a check on the mapping, not on compatibility with any one
# toolchain.
#
# A name is recognized when a real system's `uname -s` maps to it AND
# it is the spelling projects use when naming release artifacts for
# that platform.  Names are not admitted because Go added them, nor
# dropped because Go removed them; that is why this list is not
# identical to `go tool dist list`.
#
uname_os_check() {
  _shlib_os=$(uname_os)
  case "$_shlib_os" in
    aix) return 0 ;;
    darwin) return 0 ;;
    dragonfly) return 0 ;;
    freebsd) return 0 ;;
    linux) return 0 ;;
    android) return 0 ;;
    # never a GOOS; MidnightBSD reports it and names artifacts for it (PR #33)
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
  log_crit "uname_os_check '$(uname -s)' got converted to '$_shlib_os' which is not a recognized OS name"
  return 1
}
# uname_arch_check: self-check that uname_arch produced a recognized architecture name
#
# A check on the mapping, not on compatibility with any one toolchain.
# The set matches Go's GOARCH names, which is where the convention
# came from, except that ARM is spelled `armv5`, `armv6`, `armv7`
# rather than Go's `arm` plus a separate `GOARM`.
#
# Go's own list, for reference, is around here:
# https://github.com/golang/go/blob/master/src/cmd/dist/build.go#L1094
# or `go tool dist list`
#
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
    # amd64p32 was dropped from Go in 1.14 along with nacl; kept so that
    # existing callers do not start failing.
    amd64p32) return 0 ;;
  esac
  log_crit "uname_arch_check '$(uname -m)' got converted to '$_shlib_arch' which is not a recognized architecture name"
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
# http_download_curl: download a URL to a local file using curl
#
# on error: displays a message on STDERR and returns non-zero code
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

# http_download_wget: download a URL to a local file using wget
#
# unable to get server response code in a portable manner
# busybox wget (used on alpine linux) does not support "--server-response"
#
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
# http_download_fetch: download a URL to a local file using FreeBSD fetch(1)
#
# fetch(1) is the FreeBSD base-system downloader.  FreeBSD ships neither curl
# nor wget in base, so without this branch http_download fails outright on a
# stock FreeBSD box.
#
# fetch cannot send arbitrary request headers -- there is no -H equivalent.
# It honours HTTP_ACCEPT for the Accept header, which covers github_release.
# Authorization (github_api with GITHUB_TOKEN) has no equivalent, so that case
# reports a clear error instead of silently sending an unauthenticated
# request.
#
# Redirects are followed by default (-A would disable them), which release
# downloads require.
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
      # strip the field name and any leading space; set it for this command
      # only, so a caller's HTTP_ACCEPT is left alone
      _shlib_accept=${_shlib_header#*:}
      _shlib_accept=${_shlib_accept# }
      HTTP_ACCEPT="$_shlib_accept" fetch -q -o "$_shlib_local_file" "$_shlib_source_url"
      return
      ;;
  esac

  log_crit "http_download fetch cannot send '${_shlib_header%%:*}' headers; install curl or wget"
  return 1
}

# http_download_ftp: download a URL to a local file using BSD ftp(1)
#
# OpenBSD and NetBSD ship neither curl nor wget in base.  Their base
# downloader is ftp(1), which despite the name does HTTP and HTTPS
# "auto-fetch", so without this branch http_download fails outright on a stock
# box -- the same gap FreeBSD had before http_download_fetch.
#
# Two different programs answer to the name `ftp`:
#
#   OpenBSD ftp   getopt "46AaCc:dD:EeN:gik:Mmno:pP:r:S:s:TtU:uvVw:"
#                 no -H, so it cannot send request headers at all
#   tnftp         (NetBSD, and DragonFly, which also has fetch)
#                 getopt ":46Aab:defgH:iN:no:P:pq:Rr:s:T:tu:Vvx:"
#                 -H sends an arbitrary header, repeatable
#
# -o and -V are common to both: write to a named file, and stay quiet.  Both
# follow HTTP redirects, which release downloads require (OpenBSD caps it at
# 10).  -M, the OpenBSD flag for "no progress meter", does NOT exist in tnftp,
# so -V is the only portable way to keep the output quiet.
#
# Header support is probed rather than assumed, because it is a property of
# the binary and not of `uname -s`.  -Z is not a valid option in either
# program, so it prints the usage line and exits without touching the network.
# </dev/null keeps an unrelated ftp from dropping into its interactive loop:
# the netkit and inetutils clients on Linux have no auto-fetch at all, and
# neither -o nor -V, so they exit on the option before doing anything
# surprising.
#
# ACCEPT IS REFUSED EVEN WHERE -H EXISTS.  tnftp writes its own
# "Accept: */*" into every request and only then appends the -H headers
# (usr.bin/ftp/fetch.c, print_get), and nothing suppresses it.  GitHub honours
# the first Accept it sees, so `-H "Accept: application/json"` produced a
# request carrying both and came back with the HTML release page -- which
# github_release then parsed into "<!DOCTYPE html> <html lang=" as the tag.
# Verified against the live endpoint: application/json alone returns JSON,
# and "*/*" ahead of it returns HTML, as does every q-value arrangement
# ("application/json, */*;q=0" included).  Refusing is the only honest answer:
# the header is deliverable but not effective, and a silently wrong body is
# worse than a clear failure.
#
# fetch(1) does NOT have this problem -- HTTP_ACCEPT replaces its Accept
# rather than adding to it -- which is why http_download_fetch supports the
# header and this does not.
http_download_ftp() {
  _shlib_local_file=$1
  _shlib_source_url=$2
  _shlib_header=${3-}

  if [ -z "$_shlib_header" ]; then
    ftp -V -o "$_shlib_local_file" "$_shlib_source_url"
    return
  fi

  # see the note above: -H can carry Accept, but tnftp's own "Accept: */*"
  # gets there first and wins, so the response is not the one asked for
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

# http_download_python: download a URL to a local file using python3
#
# Not a base-system tool on any platform shlib targets -- this is for container
# images, which routinely ship a language runtime and no downloader at all.
# Measured: python:3.12-slim, debian:stable-slim, ubuntu:24.04 and node:22-slim
# all have neither curl nor wget, and installing a tool in any of them failed
# outright before this branch existed.
#
# python3 ONLY, never bare `python`.  That name may be python2, and pythons
# before 2.7.9 do not verify TLS certificates at all (PEP 476).  Silently
# downgrading to an unverified transport to fetch a binary is worse than
# failing, so an old interpreter is simply not used.
#
# urllib gives what fetch(1) and ftp(1) cannot: arbitrary request headers.  So
# this is the only fallback branch on which github_release can resolve
# "latest", which needs `Accept: application/json`.
#
# Redirects are followed, certificates are verified by default, and a 4xx/5xx
# raises rather than writing the error page into the destination file.
#
# The program is single-quoted, so it must contain no single quotes of its own.
http_download_python() {
  _shlib_local_file=$1
  _shlib_source_url=$2
  _shlib_header=${3-}

  python3 -c '
import sys, urllib.request

dest, url, hdr = sys.argv[1], sys.argv[2], sys.argv[3]
req = urllib.request.Request(url)
if hdr:
    name, _, value = hdr.partition(":")
    req.add_header(name.strip(), value.strip())
try:
    resp = urllib.request.urlopen(req, timeout=60)
    out = open(dest, "wb")
    while True:
        buf = resp.read(65536)
        if not buf:
            break
        out.write(buf)
    out.close()
except Exception as err:
    sys.stderr.write("python3: %s: %s\n" % (url, err))
    sys.exit(1)
' "$_shlib_local_file" "$_shlib_source_url" "$_shlib_header"
}

# http_download_node: download a URL to a local file using node
#
# The companion to http_download_python, for the container images that have a
# JavaScript runtime instead.  node:22-slim ships neither curl, wget nor
# python3 -- only node and a perl that cannot do TLS -- so without this branch
# it is one of the images where shlib simply cannot fetch anything.
#
# Uses the global fetch(), which is node 18 and newer.  That is deliberate:
# the https module has been there forever but does NOT follow redirects, and
# every GitHub release download redirects to objects.githubusercontent.com,
# so an https-based version would need its own redirect loop.  fetch()
# follows them, verifies certificates, and takes arbitrary headers.  Older
# node reports that plainly rather than failing in some obscure way.
#
# The body is streamed to disk rather than buffered: release artifacts run to
# hundreds of megabytes and Buffer.from(await r.arrayBuffer()) would hold the
# whole thing in memory.
#
# The program is single-quoted, so it must contain no single quotes of its own.
http_download_node() {
  _shlib_local_file=$1
  _shlib_source_url=$2
  _shlib_header=${3-}

  # Debian and Ubuntu shipped the interpreter as `nodejs` for years -- the
  # name `node` belonged to the ax25 package -- while the official images and
  # most other distributions use `node`.  Accept either.
  if is_command node; then
    _shlib_node=node
  else
    _shlib_node=nodejs
  fi

  "$_shlib_node" -e '
const fs = require("fs");
const { Readable } = require("stream");

const dest = process.argv[1], url = process.argv[2], hdr = process.argv[3];
if (typeof fetch !== "function") {
  process.stderr.write("node: fetch() requires node 18 or newer\n");
  process.exit(1);
}
const opts = {};
if (hdr) {
  const i = hdr.indexOf(":");
  opts.headers = { [hdr.slice(0, i).trim()]: hdr.slice(i + 1).trim() };
}
fetch(url, opts).then(function (r) {
  if (!r.ok) throw new Error("HTTP " + r.status + " " + r.statusText);
  return new Promise(function (resolve, reject) {
    const out = fs.createWriteStream(dest);
    out.on("finish", resolve);
    out.on("error", reject);
    Readable.fromWeb(r.body).pipe(out);
  });
}).catch(function (e) {
  process.stderr.write("node: " + url + ": " + e.message + "\n");
  process.exit(1);
});
' "$_shlib_local_file" "$_shlib_source_url" "$_shlib_header"
}

# http_download: download a URL to a local file, using whichever downloader exists
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
  elif is_command fetch; then
    # FreeBSD and DragonFly base ship fetch but neither curl nor wget
    http_download_fetch "$@"
    return
  elif is_command ftp; then
    # OpenBSD and NetBSD base ship neither; their downloader is ftp(1), which
    # also speaks HTTP.  Last of the base tools, because a Linux box may carry
    # a legacy ftp client that cannot fetch a URL at all.
    http_download_ftp "$@"
    return
  elif is_command python3; then
    # Not a base-system tool anywhere, so the runtimes go after every tool
    # that is.  These are for container images: python:3.12-slim and
    # node:22-slim ship a runtime and no downloader at all.
    #
    # python3 before node only to make the order stable and documented;
    # neither is more correct, and an image with both is rare.
    http_download_python "$@"
    return
  elif is_command node || is_command nodejs; then
    http_download_node "$@"
    return
  fi
  log_crit "http_download unable to find curl, wget, fetch, ftp, python3 or node"
  return 1
}

# http_copy - copies contents of a URL to stdout, or fails
#
# needed since curl is broken
#
# The body is streamed with `cat` rather than captured into a variable:
# command substitution strips trailing newlines and cannot carry NUL, so
# `body=$(cat "$_shlib_tmp")` silently corrupted binary and newline-terminated data.
# The temp file is removed on the failure path too, which it previously was not.
http_copy() {
  # explicit template: bare `mktemp` ignores TMPDIR on BSD/macOS, so the
  # temp file would land somewhere the caller cannot predict or clean up
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
# returns the last modified timestamp from a HTTP URL
# reads URL from arg 1 or stdin
#
# Requires: curl
#
http_last_modified() {
  _shlib_url=${1:-/dev/stdin}
  # curl -L = follow redirects, -s = quiet, --fail = non-zero on 4xx/5xx
  #
  # sed, not the old `grep -i | tail -c 31 | head -c 29`.  POSIX head has only
  # -n, and Solaris ships exactly that, so `head -c` printed its usage line
  # and this function returned nothing on Solaris and illumos.  The byte
  # slicing also hard-coded a 29-character date: true of RFC 1123, but the
  # field is not guaranteed to be that width, and a redirect chain emitting
  # two Last-Modified headers fed the wrong bytes in.
  #
  # [Ll] and [Mm] cover HTTP/2, which lowercases header names.
  curl -L -s --fail --head "$_shlib_url" |
    sed -n 's/^[Ll]ast-[Mm]odified:[ ]*//p' | tr -d '\r'
}
#!/bin/sh

# github_api: make an API request to api.github.com, with auth token if set
#
# Requires `http_download`
#
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
#!/bin/sh

# github_release: validates tag exists or returns latest tagged release
#
# If tag exists it is returned
# If tag is latest, the latest tag is returned
#
# Requires: http_download, is_command, log
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
  _shlib_owner_repo=$1
  _shlib_version=${2-}
  test -z "$_shlib_version" && _shlib_version="latest"
  _shlib_giturl="https://github.com/${_shlib_owner_repo}/releases/${_shlib_version}"
  _shlib_json=$(http_copy "$_shlib_giturl" "Accept:application/json")
  test -z "$_shlib_json" && return 1
  # `echo | tr -s '\n' ' '` converts the trailing newline to a space, leaving
  # sed with an unterminated final line.  SVR4 sed -- Solaris -- silently drops
  # that line and yields nothing, where BSD and GNU sed process it.  printf
  # '%s\n' puts the terminator back.
  _shlib_flat=$(echo "$_shlib_json" | tr -s '\n' ' ')
  _shlib_version=$(printf '%s\n' "$_shlib_flat" | sed 's/.*"tag_name":"//' | sed 's/".*//')
  test -z "$_shlib_version" && return 1

  # The sed above extracts whatever it finds, so a non-GitHub forge -- or an
  # error page -- yields garbage rather than a failure.  Codeberg/Forgejo, for
  # instance, returns HTML and this produced "<!DOCTYPE html> <html lang=" as
  # the "version", giving a baffling 404 downstream instead of a clear error.
  case "$_shlib_version" in
    *[!A-Za-z0-9._+-]* | "")
      log_err "github_release did not find a tag at ${_shlib_giturl} (got '$(echo "$_shlib_version" | cut -c1-40)')"
      return 1
      ;;
  esac

  echo "$_shlib_version"
}
#
# hash_md5: produce md5 hash in hex digits for a file or stdin
#
# DEPENDS:
#   log, is_command
#
# NB: do not pass /dev/stdin as a filename when reading stdin.  ksh93
# implements pipelines with socketpairs rather than pipes, and a socket
# cannot be reopened by path (open() returns ENXIO on Linux).  Calling the
# hasher with no file operand lets it read fd 0 directly, which is portable.
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
    # "MD5(name)= <hash>" / "(stdin)= <hash>"; digest is the last field
    _shlib_sum=$(openssl dgst -md5 "$@") || return 1
    echo "$_shlib_sum" | awk '{print $NF}'
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
  if [ -z "${1-}" ]; then
    set --
  else
    set -- "$1"
  fi
  if is_command gsha256sum; then
    # mac homebrew, others
    _shlib_hash=$(gsha256sum "$@") || return 1
    echo "$_shlib_hash" | cut -d ' ' -f 1
  elif is_command sha256sum; then
    # gnu, busybox
    _shlib_hash=$(sha256sum "$@") || return 1
    echo "$_shlib_hash" | cut -d ' ' -f 1
  elif is_command shasum; then
    # darwin, freebsd?
    _shlib_hash=$(shasum -a 256 "$@" 2>/dev/null) || return 1
    echo "$_shlib_hash" | cut -d ' ' -f 1
  elif is_command openssl; then
    # openssl prints "SHA2-256(name)= <hash>" (openssl 3.x),
    # "SHA256(name)= <hash>" (1.x), or "(stdin)= <hash>" when reading stdin.
    # The digest is always the last field.
    _shlib_hash=$(openssl dgst -sha256 "$@") || return 1
    echo "$_shlib_hash" | awk '{print $NF}'
  else
    log_crit "hash_sha256 unable to find command to compute sha-256 hash"
    return 1
  fi
}

# hash_sha256_verify validates a binary against a checksum.txt file
#
#
hash_sha256_verify() {
  _shlib_target=$1
  _shlib_checksums=${2-}

  if [ -z "$_shlib_checksums" ]; then
    log_err "hash_sha256_verify checksum file not specified in arg2"
    return 1
  fi

  # http://stackoverflow.com/questions/2664740/extract-file-basename-without-path-and-extension-in-bash
  _shlib_basename=${_shlib_target##*/}

  # Match the filename field EXACTLY.  A plain `grep "$_shlib_basename" file` matches
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
  _shlib_want=$(awk -v name="$_shlib_basename" '
    {
      f = $2
      sub(/^\*/, "", f)
      sub(/.*\//, "", f)
      if (f == name) print $1
    }' "$_shlib_checksums" 2>/dev/null)

  # if the file is not listed, $_shlib_want will be empty
  if [ -z "$_shlib_want" ]; then
    log_err "hash_sha256_verify unable to find checksum for '${_shlib_target}' in '${_shlib_checksums}'"
    return 1
  fi

  # more than one entry for the same name means the checksum file is
  # ambiguous.  Refuse rather than silently picking one.
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
  if [ -z "${1-}" ]; then
    set --
  else
    set -- "$1"
  fi
  if is_command gsha512sum; then
    # mac homebrew, others
    _shlib_hash=$(gsha512sum "$@") || return 1
    echo "$_shlib_hash" | cut -d ' ' -f 1
  elif is_command sha512sum; then
    # gnu, busybox
    _shlib_hash=$(sha512sum "$@") || return 1
    echo "$_shlib_hash" | cut -d ' ' -f 1
  elif is_command shasum; then
    # darwin, freebsd?
    _shlib_hash=$(shasum -a 512 "$@" 2>/dev/null) || return 1
    echo "$_shlib_hash" | cut -d ' ' -f 1
  elif is_command openssl; then
    # openssl prints "SHA2-512(name)= <hash>" (openssl 3.x),
    # "SHA512(name)= <hash>" (1.x), or "(stdin)= <hash>" when reading stdin.
    # The digest is always the last field.
    _shlib_hash=$(openssl dgst -sha512 "$@") || return 1
    echo "$_shlib_hash" | awk '{print $NF}'
  else
    log_crit "hash_sha512 unable to find command to compute sha-512 hash"
    return 1
  fi
}

# hash_sha512_verify validates a binary against a checksum.txt file
#
#
hash_sha512_verify() {
  _shlib_target=$1
  _shlib_checksums=${2-}

  if [ -z "$_shlib_checksums" ]; then
    log_err "hash_sha512_verify checksum file not specified in arg2"
    return 1
  fi

  # http://stackoverflow.com/questions/2664740/extract-file-basename-without-path-and-extension-in-bash
  _shlib_basename=${_shlib_target##*/}

  # Match the filename field EXACTLY.  A plain `grep "$_shlib_basename" file` matches
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
  _shlib_want=$(awk -v name="$_shlib_basename" '
    {
      f = $2
      sub(/^\*/, "", f)
      sub(/.*\//, "", f)
      if (f == name) print $1
    }' "$_shlib_checksums" 2>/dev/null)

  # if the file is not listed, $_shlib_want will be empty
  if [ -z "$_shlib_want" ]; then
    log_err "hash_sha512_verify unable to find checksum for '${_shlib_target}' in '${_shlib_checksums}'"
    return 1
  fi

  # more than one entry for the same name means the checksum file is
  # ambiguous.  Refuse rather than silently picking one.
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
  _shlib_giturl=$1
  _shlib_gitrepo=${_shlib_giturl##*/}   # foo.git
  _shlib_gitrepo=${_shlib_gitrepo%.git} # foo
  if [ ! -d "$_shlib_gitrepo" ]; then
    git clone "$_shlib_giturl"
  else
    (cd "$_shlib_gitrepo" && git pull >/dev/null)
  fi
}
#!/bin/sh
cat /dev/null <<EOF
------------------------------------------------------------------------
End of functions from https://github.com/client9/shlib
------------------------------------------------------------------------
EOF
