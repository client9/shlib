# main.sh: the install flow
#
# Concatenated LAST.  Everything above is definitions, so a `curl | sh` that
# gets truncated mid-transfer either does nothing at all or fails to parse --
# it cannot run a partial install.

# These files are concatenation fragments: variables set here are consumed by
# the other fragments, which shellcheck cannot see when linting one file alone.
# The assembled script IS linted -- see scripts/lint.sh.
# shellcheck disable=SC2034
PREFIX="${OWNER}/${REPO}"

# prefix every log line with the project, not the script name
log_prefix() {
  echo "$PREFIX"
}

OS=$(uname_os)
ARCH=$(uname_arch)
PLATFORM="${OS}/${ARCH}"
# Where artifacts live.  A config may set these to anything -- GitLab, Gitea,
# S3, an internal mirror -- and nothing else in the installer needs to change;
# it is only string construction.  Resolving "latest" is the separate, genuinely
# forge-specific problem, handled by latest_version().
DOWNLOAD_BASE="${DOWNLOAD_BASE:-https://github.com/${OWNER}/${REPO}/releases/download}"
RELEASES_URL="${RELEASES_URL:-https://github.com/${OWNER}/${REPO}/releases}"

# kept for configs written against the old name
GITHUB_DOWNLOAD="$DOWNLOAD_BASE"

uname_os_check || exit 1
uname_arch_check || exit 1

parse_args "$@"

normalize_platforms
check_platform || exit 1

tag_to_version || exit 1

# project hooks, after OS/ARCH/VERSION are known
adjust_format
adjust_os
adjust_arch

NAME=$(archive_name)
TARBALL=$(tarball_name)
TARBALL_URL="${DOWNLOAD_BASE}/${TAG}/${TARBALL}"

# CHECKSUM is optional; when set, execute() verifies the download against it
if is_command checksum_name; then
  CHECKSUM=$(checksum_name)
  CHECKSUM_URL="${DOWNLOAD_BASE}/${TAG}/${CHECKSUM}"
fi

log_info "found version ${VERSION} for ${PLATFORM}"

execute || exit 1
