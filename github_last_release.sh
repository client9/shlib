#!/bin/sh

# github_last_release: returns the last release version or error
#
# Requires: github_api
#
github_last_release() {
  OWNER_REPO=$1
  VERSION=$(github_api - https://api.github.com/repos/${OWNER_REPO}/releases/latest | grep -m 1 "\"name\":" | cut -d ":" -f 2 | tr -d ' ",')
  if [ -z "${VERSION}" ]; then
    echo "Unable to determine latest release for ${OWNER_REPO}"
    return 1
  fi
  echo ${VERSION}
fi
