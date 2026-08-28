#!/bin/sh

# github_release: validates tag exists or returns latest tagged release
#
# If tag exists it is returned
# If tag is latest, the latest tag is returned
#
# Requires: http_download, is_command, log
#
# hack to extract version from output is based on
#
# https://github.com/golang/dep/blob/master/install.sh
#
#  1. tr -s '\n' ' ' --> make sure output is exactly one line
#  2. sed 's/.*"tag_name":"//'  --> remove everything before
#  3. sed 's/".*//' --> remove everything after
#
#  what remains is the version number
#
github_release() {
  _shlib_owner_repo=$1
  _shlib_version=$2
  test -z "$_shlib_version" && _shlib_version="latest"
  _shlib_giturl="https://github.com/${_shlib_owner_repo}/releases/${_shlib_version}"
  _shlib_json=$(http_copy "$_shlib_giturl" "Accept:application/json")
  test -z "$_shlib_json" && return 1
  _shlib_version=$(echo "$_shlib_json" | tr -s '\n' ' ' | sed 's/.*"tag_name":"//' | sed 's/".*//')
  test -z "$_shlib_version" && return 1

  # The sed above extracts whatever it finds, so a non-GitHub forge -- or an
  # error page -- yields garbage rather than a failure.  Codeberg/Forgejo, for
  # instance, returns HTML and this produced "<!DOCTYPE html> <html lang=" as
  # the "version", giving a baffling 404 downstream instead of a clear error.
  case "$_shlib_version" in
    *[!A-Za-z0-9._+-]* | "")
      log_err "github_release did not find a tag at ${_shlib_giturl} (got '$(echo "$_shlib_version" | cut -c1-40)')"
      return 1
      ;;
  esac

  echo "$_shlib_version"
}
