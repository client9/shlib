#!/bin/sh

# github_api: make a api request to api.github.com with auth token
#
# Requires `http_download`
#
github_api() {
  DEST=$1
  SOURCE=$2
  header=""
  case "$SOURCE" in
  https://api.github.com*)
     test -z "$GITHUB_TOKEN" || header="Authorization: token $GITHUB_TOKEN"
     ;;
  esac
  http_download "$DEST" "$SOURCE" "$HEADER"
}
