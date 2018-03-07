#!/bin/sh

# github_last_release: returns the last release version or error
#
# Requires: http_download, is_command
#
github_last_release() {
  owner_repo=$1
  version=$2
  test -z "$version" && version="latest"
  giturl="https://github.com/${owner_repo}/releases/${version}"
  html=$(http_download "-" "$giturl" "Accept:application/json")
  # remove everything before tag_name:", and then everything after the next "
  version=$(echo "$html" | sed 's/.*"tag_name":"//' | sed 's/".*//')
  test -z "$version" && return 1
  echo "$version"
}
