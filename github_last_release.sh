#!/bin/sh

# github_last_release: returns the last release version or error
#
# Requires: github_api
#
github_last_release() {
  owner_repo=$1
  # we capture the entire output, then grep -m 1 (only take first result)
  # this prevents curl from issuing "(23) failed to write body" errors
  # when grep closes the pipe
  html=$(github_api - https://api.github.com/repos/${owner_repo}/releases/latest)
  version=$(echo $html | grep -m 1 "\"name\":" | cut -d ":" -f 2 | tr -d ' ",')
  if [ -z "$version" ]; then
    return 1
  fi
  echo "$version"
}
