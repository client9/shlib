# http_download_curl: download a URL to a local file using curl
#
# on error: displays a message on STDERR and returns non-zero code
http_download_curl() {
  _shlib_local_file=$1
  _shlib_source_url=$2
  _shlib_header=$3
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
  _shlib_header=$3
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
  _shlib_header=$3

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
    # FreeBSD base ships fetch but neither curl nor wget
    http_download_fetch "$@"
    return
  fi
  log_crit "http_download unable to find curl, wget or fetch"
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
  if ! http_download "${_shlib_tmp}" "$1" "$2"; then
    rm -f "${_shlib_tmp}"
    return 1
  fi
  cat "${_shlib_tmp}"
  _shlib_rc=$?
  rm -f "${_shlib_tmp}"
  return $_shlib_rc
}
