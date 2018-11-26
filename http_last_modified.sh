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
