# fixture config used by runner_test.sh
# shellcheck disable=SC2034
OWNER=example
REPO=testproj
BINARY=testbin
FORMAT=tar.gz
PLATFORMS="darwin/amd64 darwin/arm64 linux/amd64 linux/arm64"
archive_name() { echo "${BINARY}_${VERSION}_${OS}_${ARCH}"; }
