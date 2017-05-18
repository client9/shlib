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
