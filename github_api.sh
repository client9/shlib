#!/bin/sh

# github_api: make a api request to api.github.com with auth token
#
# Requires `http_download`
#
github_api() {
  _shlib_local_file=$1
  _shlib_source_url=$2
  _shlib_header=""
  case "$_shlib_source_url" in
    https://api.github.com*)
      test -z "$GITHUB_TOKEN" || _shlib_header="Authorization: token $GITHUB_TOKEN"
      ;;
  esac
  http_download "$_shlib_local_file" "$_shlib_source_url" "$_shlib_header"
}
