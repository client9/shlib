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
