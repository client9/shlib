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
    # also speaks HTTP.  Last, because a Linux box may carry a legacy ftp
    # client that cannot fetch a URL at all.
    http_download_ftp "$@"
    return
  fi
  log_crit "http_download unable to find curl, wget, fetch or ftp"
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
