# runner.sh: fixed logic for a shlib-based install script
#
# This file defines functions only.  It executes nothing, so it can be sourced
# by tests.  The flow lives in main.sh, which is concatenated last so that a
# truncated `curl | sh` either does nothing or fails to parse, rather than
# doing half the work.
#
# The per-project settings live in a config file concatenated ahead of this
# one.  See config.sh.example.
#
# DEPENDS: log, is_command, http_download, github_release, hash_sha256,
#          mktmpdir, untar, install_exe, uname_os, uname_arch

usage() {
  _shlib_this=$1
  cat <<EOF
$_shlib_this: download binaries for ${OWNER}/${REPO}

Usage: $_shlib_this [-b bindir] [-d] [tag]
  -b  install directory (default ${BINDIR})
  -d  turn on debug logging
  tag a tag from ${RELEASES_URL}
      if missing, the latest release is used
EOF
  exit 2
}

parse_args() {
  BINDIR=${BINDIR:-./bin}
  while getopts "b:dh?x" arg; do
    case "$arg" in
      b) BINDIR="$OPTARG" ;;
      d) log_set_priority 10 ;;
      h | \?) usage "$0" ;;
      x) set -x ;;
      *) usage "$0" ;;
    esac
  done
  shift $((OPTIND - 1))
  # No tag argument is the normal `curl | sh` case, so $1 may be unset.  An
  # install script is exactly the kind of thing a careful user runs under
  # `set -u`, where a bare $1 aborts before anything is installed.
  TAG=${1-}
}

# check_platform verifies that this project actually publishes something for
# the detected OS/ARCH.
#
# PLATFORMS is declared by the project's config: the maintainer already knows
# which combinations they build, so this needs no network call.  Without it a
# user on an unsupported platform gets a bare 404 from the download, which is
# what made an unsupported-Windows install look like a library bug.
# normalize_platforms folds newlines and runs of whitespace in PLATFORMS down
# to single spaces, so a config may list platforms across several indented
# lines.  main.sh calls this before check_platform.
#
# It is deliberately NOT done inside check_platform: ksh93 loses a function's
# stderr when that function contains a command substitution and the caller
# captures it with `$(f 2>&1)`, which silently swallowed the error message.
normalize_platforms() {
  PLATFORMS=$(printf '%s' "${PLATFORMS-}" | tr '\t\n' '  ' | tr -s ' ')
  PLATFORMS=${PLATFORMS# }
  PLATFORMS=${PLATFORMS% }
}

# check_platform verifies that this project actually publishes something for
# the detected OS/ARCH.
#
# PLATFORMS is declared by the project's config: the maintainer already knows
# which combinations they build, so this needs no network call.  Without it a
# user on an unsupported platform gets a bare 404 from the download, which is
# what made an unsupported-Windows install look like a library bug.
check_platform() {
  # empty PLATFORMS means "do not check"
  test -z "${PLATFORMS-}" && return 0

  # Substring match on a space-padded list rather than `for p in $PLATFORMS`:
  # zsh does not word-split unquoted parameters, so the loop would compare the
  # whole list against one platform and never match.
  # PLATFORM is set by main.sh, which the linter cannot see from here
  # shellcheck disable=SC2153
  case " ${PLATFORMS} " in
    *" ${PLATFORM} "*) return 0 ;;
  esac

  # log_prefix already prints OWNER/REPO, so do not repeat it here
  log_crit "no binary published for ${PLATFORM}"
  log_crit "available platforms: ${PLATFORMS}"
  return 1
}

# tag_to_version resolves TAG (possibly empty) into TAG and VERSION.
# VERSION is TAG without any leading "v", which is what release filenames
# usually use.
tag_to_version() {
  # TAG may be unset -- parse_args fills it from an optional argument, and a
  # caller need not have gone through parse_args at all.  Normalise it once,
  # here, so the rest of this function and latest_version can use it plainly
  # instead of every reference needing its own ${TAG-}.
  TAG=${TAG-}
  # not "checking GitHub": latest_version may point anywhere
  if [ -z "${TAG}" ]; then
    log_info "checking for latest tag"
  else
    log_info "checking for tag '${TAG}'"
  fi
  _shlib_realtag=$(latest_version "${TAG}") && true
  if test -z "$_shlib_realtag"; then
    log_crit "unable to find '${TAG}' - use 'latest' or see ${RELEASES_URL} for details"
    return 1
  fi
  TAG="$_shlib_realtag"
  # consumed by the project's archive_name(), which shellcheck cannot see
  # shellcheck disable=SC2034
  VERSION=${TAG#v}
}

# Default no-op hooks.
#
# The project config is concatenated AHEAD of this file, so a plain definition
# here would clobber the project's version.  Define each one only when the
# config did not, which keeps the config's override authoritative.
#
# Uses `command -v` directly rather than shlib's is_command: if is_command were
# somehow unavailable the test would fail open (status 127 -> `!` -> true) and
# silently overwrite the project's hook.  `command -v` is a shell builtin and
# is always there.
if ! command -v adjust_format >/dev/null 2>&1; then
  adjust_format() { :; }
fi
if ! command -v adjust_os >/dev/null 2>&1; then
  adjust_os() { :; }
fi
if ! command -v adjust_arch >/dev/null 2>&1; then
  adjust_arch() { :; }
fi

# binary_path maps a binary name to its location INSIDE the archive.
#
# Many projects put the binary at the archive root, which is the default.
# Others wrap everything in a versioned directory, e.g.
#   golangci-lint-2.13.1-darwin-arm64/golangci-lint
# Those configs define:
#   binary_path() { echo "${NAME}/$1"; }
if ! command -v binary_path >/dev/null 2>&1; then
  binary_path() { echo "$1"; }
fi

# unpack extracts the downloaded file into the current directory.
#
# This is a hook because not every project ships an archive.  A bare-binary
# release -- hadolint publishes hadolint-linux-x86_64 and nothing else -- has
# nothing to extract, and untar would refuse it outright.  Those configs do:
#   unpack() { :; }
#   binary_path() { echo "${TARBALL}"; }
#
# Deliberately SEPARATE from FORMAT.  FORMAT is the filename suffix; whether
# the download needs unpacking is a different question, and the two do not
# agree: hadolint's windows asset is hadolint-windows-x86_64.exe -- a non-empty
# suffix that is still not an archive.  A "FORMAT=binary" sentinel could not
# express that combination.
if ! command -v unpack >/dev/null 2>&1; then
  unpack() { untar "$1"; }
fi

# tarball_name: NAME plus FORMAT's suffix, when there is one.
#
# `${FORMAT:+...}` rather than a bare ".${FORMAT}", so a bare-binary config can
# leave FORMAT empty without producing a trailing dot.  That form is
# nounset-safe with FORMAT entirely unset, which matters because an install
# script is exactly the kind of thing run under `set -eu`.
#
# Lives here rather than inline in main.sh so it can be unit tested: runner.sh
# defines, main.sh runs.
tarball_name() {
  echo "${NAME}${FORMAT:+.${FORMAT}}"
}

# latest_version resolves "newest release" to a tag.
#
# This is the one genuinely forge-specific piece.  The default asks GitHub,
# which answers `releases/latest` with JSON when sent `Accept: application/json`.
# No other forge does: GitLab returns no JSON body and Forgejo returns HTML.
#
# A project hosted elsewhere overrides this with whatever its host provides:
#
#   latest_version() {
#     http_copy "https://gitlab.example/api/v4/projects/42/releases" |
#       sed 's/.*"tag_name":"//; s/".*//'
#   }
#
# shlib deliberately does not try to know other forges' APIs -- that is the
# project's own knowledge, and every variation would arrive here as a bug.
if ! command -v latest_version >/dev/null 2>&1; then
  latest_version() { github_release "${OWNER}/${REPO}" "$1"; }
fi

# execute wraps every destructive operation in one function, so that a
# `curl | sh` truncated mid-download cannot leave a half-installed mess.
execute() {
  _shlib_tmpdir=$(mktmpdir) || return 1
  log_debug "downloading files into ${_shlib_tmpdir}"

  http_download "${_shlib_tmpdir}/${TARBALL}" "${TARBALL_URL}" || return 1

  if [ -n "${CHECKSUM-}" ]; then
    http_download "${_shlib_tmpdir}/${CHECKSUM}" "${CHECKSUM_URL}" || return 1
    hash_sha256_verify "${_shlib_tmpdir}/${TARBALL}" "${_shlib_tmpdir}/${CHECKSUM}" || return 1
  fi

  (cd "${_shlib_tmpdir}" && unpack "${TARBALL}") || return 1

  mkdir -p "${BINDIR}" || return 1

  # Peel the list with parameter expansion rather than `for b in ${BINARIES}`:
  # zsh does not word-split unquoted parameters, so a multi-binary list would
  # be treated as one filename.
  _shlib_bins=$(printf '%s' "${BINARIES:-$BINARY}" | tr '\t\n' '  ' | tr -s ' ')
  _shlib_bins=${_shlib_bins# }
  _shlib_bins=${_shlib_bins% }
  while [ -n "${_shlib_bins}" ]; do
    case "${_shlib_bins}" in
      *" "*)
        _shlib_binexe=${_shlib_bins%% *}
        _shlib_bins=${_shlib_bins#* }
        ;;
      *)
        _shlib_binexe=${_shlib_bins}
        _shlib_bins=""
        ;;
    esac
    if [ "$OS" = "windows" ]; then
      _shlib_binexe="${_shlib_binexe}.exe"
    fi
    _shlib_srcpath=$(binary_path "${_shlib_binexe}")

    install_exe "${_shlib_tmpdir}/${_shlib_srcpath}" "${BINDIR}/${_shlib_binexe}" || return 1
    log_info "installed ${BINDIR}/${_shlib_binexe}"
  done
  rm -rf "${_shlib_tmpdir}"
}
