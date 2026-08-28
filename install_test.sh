# Tests for install/runner.sh.
#
# This file drives code it sources, so shellcheck cannot see the connections:
#   SC1091 - sourced files are generated or path-relative
#   SC2034 - variables here are consumed by runner.sh
#   SC2329 - stub functions are invoked indirectly, by execute()
# shellcheck disable=SC1091,SC2034,SC2329
. ./assert.sh
. ./dist/shlib.min.sh
. ./install/fixtures/config.sh
. ./install/runner.sh

# runner.sh defines functions only, so sourcing it runs nothing.  main.sh --
# which does run the flow -- is deliberately NOT sourced here.

# --- parse_args ----------------------------------------------------------

test_parse_args_defaults() {
  OPTIND=1
  BINDIR=""
  parse_args
  assertEquals "./bin" "$BINDIR" "parse_args: default BINDIR"
  assertEquals "" "$TAG" "parse_args: no tag by default"
}

test_parse_args_bindir() {
  OPTIND=1
  BINDIR=""
  parse_args -b /opt/bin
  assertEquals "/opt/bin" "$BINDIR" "parse_args: -b sets BINDIR"
}

test_parse_args_tag() {
  OPTIND=1
  BINDIR=""
  parse_args -b /opt/bin v1.2.3
  assertEquals "v1.2.3" "$TAG" "parse_args: positional tag"
}

# --- check_platform ------------------------------------------------------

test_platform_supported() {
  normalize_platforms
  PLATFORM="linux/amd64"
  assertTrue "check_platform" "check_platform: supported platform passes"
}

test_platform_unsupported() {
  PLATFORM="windows/arm64"
  assertFalse "check_platform 2>/dev/null" "check_platform: unsupported platform fails"
}

# the message must name what IS available -- a bare failure is what made an
# unsupported platform look like a library bug
test_platform_message() {
  PLATFORM="windows/arm64"
  got=$(check_platform 2>&1)
  case "$got" in
    *"windows/arm64"*) assertTrue "true" "check_platform: names the bad platform" ;;
    *) assertTrue "false" "check_platform: message omits the platform: $got" ;;
  esac
  case "$got" in
    *"linux/amd64"*) assertTrue "true" "check_platform: lists available platforms" ;;
    *) assertTrue "false" "check_platform: message omits alternatives: $got" ;;
  esac
}

# a config may spread PLATFORMS across indented lines; normalize_platforms
# folds that so the space-padded match still works
test_normalize_platforms() {
  saved=$PLATFORMS
  PLATFORMS="darwin/amd64 darwin/arm64
             linux/amd64 linux/arm64"
  normalize_platforms
  assertEquals "darwin/amd64 darwin/arm64 linux/amd64 linux/arm64" "$PLATFORMS" "normalize_platforms: folds newlines and indentation"
  PLATFORM="linux/arm64"
  assertTrue "check_platform" "normalize_platforms: last entry of a multi-line list matches"
  PLATFORM="darwin/amd64"
  assertTrue "check_platform" "normalize_platforms: first entry matches"
  PLATFORMS=$saved
}

test_platform_empty_skips() {
  saved=$PLATFORMS
  PLATFORMS=""
  PLATFORM="haiku/m68k"
  assertTrue "check_platform" "check_platform: empty PLATFORMS skips the check"
  PLATFORMS=$saved
}

# --- archive_name --------------------------------------------------------

# the config's function is a lazily-evaluated template: it runs after
# VERSION/OS/ARCH are set, which is what the Go text/template did
test_archive_name() {
  VERSION=1.2.3
  OS=linux
  ARCH=amd64
  assertEquals "testbin_1.2.3_linux_amd64" "$(archive_name)" "archive_name: expands current VERSION/OS/ARCH"
  VERSION=9.9.9
  assertEquals "testbin_9.9.9_linux_amd64" "$(archive_name)" "archive_name: re-expands after VERSION changes"
}

# --- adjust_* hooks ------------------------------------------------------

test_adjust_defaults_are_noops() {
  OS=linux
  ARCH=amd64
  FORMAT=tar.gz
  adjust_os
  adjust_arch
  adjust_format
  assertEquals "linux" "$OS" "adjust_os: default is a no-op"
  assertEquals "amd64" "$ARCH" "adjust_arch: default is a no-op"
  assertEquals "tar.gz" "$FORMAT" "adjust_format: default is a no-op"
}

test_adjust_override_wins() {
  adjust_os() { case ${OS} in linux) OS=Linux ;; esac }
  OS=linux
  adjust_os
  assertEquals "Linux" "$OS" "adjust_os: a config override replaces the default"
  adjust_os() { :; }
}

# --- tarball_name --------------------------------------------------------

# FORMAT is a filename SUFFIX, not a format identifier: it is concatenated onto
# NAME and never compared against anything.  So it has to tolerate being empty,
# for a project that publishes bare binaries with no suffix at all.
test_tarball_name() {
  NAME=widget_1.2.3_linux_amd64
  FORMAT=tar.gz
  assertEquals "widget_1.2.3_linux_amd64.tar.gz" "$(tarball_name)" \
    "tarball_name: appends FORMAT as a suffix"
  FORMAT=zip
  assertEquals "widget_1.2.3_linux_amd64.zip" "$(tarball_name)" \
    "tarball_name: re-expands after adjust_format changes FORMAT"
  # a suffix that is not an archive -- hadolint's windows asset
  FORMAT=exe
  assertEquals "widget_1.2.3_linux_amd64.exe" "$(tarball_name)" \
    "tarball_name: a non-archive suffix is just a suffix"
  # the case this function exists for: no suffix, and NO trailing dot
  FORMAT=""
  assertEquals "widget_1.2.3_linux_amd64" "$(tarball_name)" \
    "tarball_name: empty FORMAT leaves no trailing dot"
  FORMAT=tar.gz
}

# --- unpack --------------------------------------------------------------

# These run in a fresh shell rather than redefining functions here: it mirrors
# the real concatenation order (config first, then the library), and it avoids
# the ksh93 hazards documented below -- a function redefined inside a subshell
# is not honoured by the caller, and repeated redefine/`unset -f` crashed it.
test_unpack_default_is_untar() {
  got=$(sh -c '. ./install/runner.sh
    untar() { echo "UNTAR:$1"; }
    unpack somefile.tar.gz')
  assertEquals "UNTAR:somefile.tar.gz" "$got" \
    "unpack: the default hands the file to untar"
}

# the config is concatenated BEFORE the library, so its definition must win
test_unpack_override_wins() {
  got=$(sh -c 'unpack() { echo "MINE:$1"; }
    . ./install/runner.sh
    untar() { echo "UNTAR:$1"; }
    unpack somefile')
  assertEquals "MINE:somefile" "$got" \
    "unpack: a config override is not replaced by the default"
}

# --- execute -------------------------------------------------------------

# Stubs are installed once, at the top level, and their behaviour is driven by
# variables rather than by redefining them per scenario.
#
# Two shell differences forced this shape:
#   - ksh93 does NOT honour a function redefined inside a subshell; the caller
#     still resolves the outer definition.  So stubs cannot be scoped with ( ).
#   - repeatedly redefining and `unset -f`-ing functions made ksh93 crash.
# These tests therefore run last, and the stubs are allowed to persist.

STUB_MARKER=""
STUB_VERIFY_RC=0
STUB_UNPACK_NOOP=""

http_download() { echo stub >"$1"; }

# Driven by a variable rather than redefined per scenario, for the reasons
# above.  Empty STUB_UNPACK_NOOP is the ordinary archive path, so every
# existing execute test below is unaffected.
unpack() {
  if [ -n "$STUB_UNPACK_NOOP" ]; then
    return 0
  fi
  untar "$1"
}

# Mirrors the real untar in one respect that matters here: it REFUSES a file
# with no recognised archive suffix (untar.sh:36).  Without that, a test for
# the bare-binary path would pass even if execute() still called untar
# directly, because a stub that always succeeds hides the whole bug.
untar() {
  case "$1" in
    *.tar.gz | *.tgz | *.tar | *.zip) ;;
    *)
      log_err "untar unknown archive format for $1"
      return 1
      ;;
  esac
  echo '#!/bin/sh' >testbin
  chmod +x testbin
}

hash_sha256_verify() {
  test -z "$STUB_MARKER" || echo yes >"$STUB_MARKER"
  return "$STUB_VERIFY_RC"
}

test_execute() {
  workdir=$(mktmpdir)
  BINDIR="$workdir/bin"
  BINARY=testbin
  BINARIES=""
  TARBALL=testbin_1.2.3_linux_amd64.tar.gz
  TARBALL_URL=https://example.invalid/$TARBALL
  CHECKSUM=""
  OS=linux

  execute >/dev/null 2>&1
  assertEquals "0" "$?" "execute: succeeds with a stubbed download"
  assertTrue "[ -x '$workdir/bin/testbin' ]" "execute: installs the binary into BINDIR"
  rm -rf "$workdir"
}

test_execute_verifies_checksum() {
  workdir=$(mktmpdir)
  BINDIR="$workdir/bin"
  BINARY=testbin
  BINARIES=""
  TARBALL=testbin.tar.gz
  TARBALL_URL=https://example.invalid/$TARBALL
  CHECKSUM=checksums.txt
  CHECKSUM_URL=https://example.invalid/checksums.txt
  OS=linux
  STUB_MARKER="$workdir/verified"
  STUB_VERIFY_RC=0

  execute >/dev/null 2>&1
  assertTrue "[ -f '$workdir/verified' ]" "execute: verifies the checksum when CHECKSUM is set"
  rm -rf "$workdir"
  STUB_MARKER=""
}

# a failed checksum must abort before anything is installed
test_execute_bad_checksum() {
  workdir=$(mktmpdir)
  BINDIR="$workdir/bin"
  BINARY=testbin
  BINARIES=""
  TARBALL=testbin.tar.gz
  TARBALL_URL=https://example.invalid/$TARBALL
  CHECKSUM=checksums.txt
  CHECKSUM_URL=https://example.invalid/checksums.txt
  OS=linux
  STUB_VERIFY_RC=1

  execute >/dev/null 2>&1
  assertNotEquals "0" "$?" "execute: a failed checksum aborts"
  assertFalse "[ -f '$workdir/bin/testbin' ]" "execute: nothing installed when the checksum fails"
  rm -rf "$workdir"
  STUB_VERIFY_RC=0
}

# A bare-binary release: nothing to unpack, and the download itself is the
# binary.  This is the path hadolint takes -- the whole reason unpack is a hook.
test_execute_bare_binary() {
  workdir=$(mktmpdir)
  BINDIR="$workdir/bin"
  BINARY=testbin
  BINARIES=""
  NAME=testbin-linux-x86_64
  TARBALL=$NAME
  TARBALL_URL=https://example.invalid/$TARBALL
  CHECKSUM=""
  OS=linux
  STUB_UNPACK_NOOP=1
  binary_path() { echo "${TARBALL}"; }

  execute >/dev/null 2>&1
  assertEquals "0" "$?" "execute: succeeds with no archive to unpack"
  assertTrue "[ -x '$workdir/bin/testbin' ]" \
    "execute: the downloaded file is installed as the binary, and is executable"

  binary_path() { echo "$1"; }
  STUB_UNPACK_NOOP=""
  rm -rf "$workdir"
}

# --- forge independence --------------------------------------------------

# Only two seams are GitHub-specific: where artifacts live (DOWNLOAD_BASE,
# pure string construction) and how "latest" resolves (latest_version, which
# genuinely differs per forge -- GitLab returns no JSON and Forgejo returns
# HTML).  Override both and nothing else in the installer knows the difference.
test_download_base_override() {
  d=$(mktmpdir)
  cat >"$d/config.sh" <<'CFG'
OWNER=example
REPO=widget
BINARY=widget
FORMAT=tar.gz
PLATFORMS="linux/amd64"
DOWNLOAD_BASE="https://downloads.example.internal/widget"
RELEASES_URL="https://git.example.internal/example/widget/releases"
latest_version() { test -n "$1" && echo "$1" || echo "v9.9.9"; }
archive_name() { echo "${BINARY}_${VERSION}_${OS}_${ARCH}"; }
CFG
  got=$(sh -c ". '$d/config.sh'
    . ./dist/shlib.min.sh
    . ./install/runner.sh
    OS=linux; ARCH=amd64; PLATFORM=linux/amd64
    parse_args
    tag_to_version >/dev/null 2>&1
    NAME=\$(archive_name)
    echo \"\${DOWNLOAD_BASE}/\${TAG}/\$(tarball_name)\"")
  assertEquals "https://downloads.example.internal/widget/v9.9.9/widget_9.9.9_linux_amd64.tar.gz" \
    "$got" "forge: DOWNLOAD_BASE and latest_version override cleanly"
  rm -rf "$d"
}

# the default still points at GitHub when a config says nothing
test_download_base_defaults_to_github() {
  d=$(mktmpdir)
  got=$(sh -c 'OWNER=securego; REPO=gosec
    DOWNLOAD_BASE="${DOWNLOAD_BASE:-https://github.com/${OWNER}/${REPO}/releases/download}"
    echo "$DOWNLOAD_BASE"')
  assertEquals "https://github.com/securego/gosec/releases/download" "$got" \
    "forge: defaults to GitHub when unset"
  rm -rf "$d"
}

# the log line must not claim GitHub when latest_version points elsewhere
test_no_github_in_log_when_overridden() {
  d=$(mktmpdir)
  got=$(sh -c '. ./dist/shlib.min.sh
    . ./install/runner.sh
    OWNER=x; REPO=y
    latest_version() { echo v1.0.0; }
    TAG=""
    tag_to_version 2>&1 >/dev/null' | tr -d '\n')
  case "$got" in
    *GitHub*) assertTrue "false" "forge: log still says GitHub [$got]" ;;
    *) assertTrue "true" "forge: log does not assume GitHub" ;;
  esac
  rm -rf "$d"
}

# github_release must reject a response that is not GitHub JSON.  It used to
# return whatever sed found, so a Forgejo instance yielded
# "<!DOCTYPE html> <html lang=" as the version and a baffling 404 downstream.
test_github_release_rejects_html() {
  got=$(sh -c '. ./dist/shlib.min.sh
    http_copy() { printf "<!DOCTYPE html>\n<html lang=\"en\">\n"; }
    github_release owner/repo 2>/dev/null; echo "rc=$?"' | tail -1)
  assertEquals "rc=1" "$got" "github_release: rejects an HTML response"

  got=$(sh -c '. ./dist/shlib.min.sh
    http_copy() { printf "{\"tag_name\":\"v1.2.3-rc1+build.5\"}"; }
    github_release owner/repo 2>/dev/null')
  assertEquals "v1.2.3-rc1+build.5" "$got" "github_release: accepts a legitimate odd tag"
}

# github_release failed on Solaris returning an empty tag, and the cause was
# not reproducible anywhere else.  These check each stage of the pipeline
# separately so the next run says which one breaks, instead of only that the
# whole thing did.
#
# Note the rejects-HTML assertion above expects rc=1, so it passes on ANY
# failure -- it cannot distinguish "correctly rejected" from "broken".
test_github_release_stages() {
  _json='{"tag_name":"v1.2.3-rc1+build.5"}'

  # 1. tr flattening.  Solaris tr was suspected, but normalize_platforms uses
  #    the same escapes on a string containing "linux" and passes there.
  # echo appends a newline, which tr turns into a trailing space -- so compare
  # the property that matters rather than the exact string: an SVR4 tr that
  # treats '\n' as the two characters backslash and n would translate every
  # 'n', mangling "tag_name" into "tag_ ame".
  _flat=$(echo "$_json" | tr -s '\n' ' ')
  case "$_flat" in
    *'"tag_name":"'*) assertTrue "true" "github_release stage 1: tr leaves tag_name intact" ;;
    *) assertTrue "false" "github_release stage 1: tr mangled the JSON [$_flat]" ;;
  esac

  # 2. sed extraction.  printf '%s\n', not '%s': SVR4 sed (Solaris) drops a
  #    final line with no terminator, which is exactly what broke here.
  _tag=$(printf '%s\n' "$_flat" | sed 's/.*"tag_name":"//' | sed 's/".*//')
  assertEquals "v1.2.3-rc1+build.5" "$_tag" "github_release stage 2: sed extracts the tag"

  # 3. the validation case.  Character ranges are collation-dependent, so a
  #    non-C locale is the remaining suspect.
  case "$_tag" in
    *[!A-Za-z0-9._+-]* | "")
      assertTrue "false" "github_release stage 3: validation rejected '$_tag' (LC_ALL=${LC_ALL:-unset} LANG=${LANG:-unset})"
      ;;
    *)
      assertTrue "true" "github_release stage 3: validation accepts the tag"
      ;;
  esac

  # 4. the whole function, with the network stubbed out
  _got=$(sh -c '. ./dist/shlib.min.sh
    http_copy() { printf "{\"tag_name\":\"v1.2.3-rc1+build.5\"}"; }
    github_release owner/repo 2>/dev/null')
  assertEquals "v1.2.3-rc1+build.5" "$_got" "github_release stage 4: end to end"
}

test_github_release_stages
test_github_release_rejects_html
test_download_base_override
test_download_base_defaults_to_github
test_no_github_in_log_when_overridden

# --- assembled script ----------------------------------------------------

# The real artifact is config.sh + install-base.sh concatenated.  Assembly
# order is load-bearing: the config comes FIRST, so runner.sh must not clobber
# a hook the config already defined, and main.sh must come LAST so a truncated
# `curl | sh` cannot run a partial install.
test_assembled_script() {
  if [ ! -f ./dist/install-base.sh ]; then
    assert_skip "dist/install-base.sh not built - run 'make dist'"
    return 0
  fi
  d=$(mktmpdir)
  cat >"$d/config.sh" <<'CFG'
OWNER=example
REPO=testproj
BINARY=testbin
FORMAT=tar.gz
PLATFORMS="linux/amd64"
archive_name() { echo "${BINARY}_${VERSION}_${OS}_${ARCH}"; }
adjust_os() { case ${OS} in linux) OS=Linux ;; esac; }
CFG
  cat "$d/config.sh" ./dist/install-base.sh >"$d/install.sh"

  assertTrue "sh -n '$d/install.sh'" "assembled: parses"

  # the config's adjust_os must survive; runner.sh only fills in absent hooks
  got=$(sh -c ". '$d/config.sh'; . ./dist/shlib.min.sh; . ./install/runner.sh; OS=linux; adjust_os; echo \$OS")
  assertEquals "Linux" "$got" "assembled: config hook is not clobbered by the default"

  # main.sh runs the flow, so it must be last
  assertTrue "tail -5 '$d/install.sh' | grep -q execute" "assembled: the flow is at the end"

  rm -rf "$d"
}

# --- examples ------------------------------------------------------------

# Each example config must produce a filename that actually exists in the
# release it was written against.  Expectations are real asset names, so if
# the runner's contract drifts these fail.
#
# Each check runs in its own `sh -c` process: the configs define adjust_*
# hooks, and those definitions would otherwise leak between checks.

# check_example <config> <version> <os> <arch> <expected archive> <expected checksum>
check_example() {
  _cfg=$1
  _got=$(sh -c '. ./install/examples/'"$_cfg"'
    . ./dist/shlib.min.sh
    . ./install/runner.sh
    VERSION='"$2"'; OS='"$3"'; ARCH='"$4"'
    adjust_format; adjust_os; adjust_arch
    NAME=$(archive_name)
    echo "$(tarball_name) $(checksum_name)"')
  assertEquals "$5 $6" "$_got" "example $_cfg: $3/$4"
}

# check_example_path <cfg> <tag> <os> <arch> <expected tarball> <expected path>
#
# Like check_example, but for a project that publishes no checksum file, and it
# pins binary_path too -- shellcheck's differs between the unix tarballs and
# the windows zip.  TAG is set as well as VERSION because these filenames carry
# the tag verbatim.  The `.exe` suffixing mirrors execute() in runner.sh.
check_example_path() {
  _cfg=$1
  _got=$(sh -c '. ./install/examples/'"$_cfg"'
    . ./dist/shlib.min.sh
    . ./install/runner.sh
    TAG='"$2"'; VERSION=${TAG#v}; OS='"$3"'; ARCH='"$4"'
    adjust_format; adjust_os; adjust_arch
    NAME=$(archive_name)
    TARBALL=$(tarball_name)
    b=$BINARY
    if [ "$OS" = windows ]; then b="${b}.exe"; fi
    echo "${TARBALL} $(binary_path "$b")"')
  assertEquals "$5 $6" "$_got" "example $_cfg: $3/$4"
}

# securego/gosec v2.29.0 -- canonical spellings, tar.gz everywhere
test_example_gosec() {
  check_example gosec.sh 2.29.0 darwin arm64 \
    gosec_2.29.0_darwin_arm64.tar.gz gosec_2.29.0_checksums.txt
  check_example gosec.sh 2.29.0 windows amd64 \
    gosec_2.29.0_windows_amd64.tar.gz gosec_2.29.0_checksums.txt
}

# ory/hydra v26.2.0 -- renamed os/arch, hyphen, zip on windows
test_example_hydra() {
  check_example hydra.sh 26.2.0 darwin arm64 \
    hydra_26.2.0-macOS_arm64.tar.gz checksums.txt
  check_example hydra.sh 26.2.0 linux amd64 \
    hydra_26.2.0-linux_64bit.tar.gz checksums.txt
  check_example hydra.sh 26.2.0 windows amd64 \
    hydra_26.2.0-windows_64bit.zip checksums.txt
}

# go-task/task v3.53.1 -- no version in the name, armv7 folds to arm
test_example_task() {
  check_example task.sh 3.53.1 darwin arm64 \
    task_darwin_arm64.tar.gz task_checksums.txt
  check_example task.sh 3.53.1 linux armv7 \
    task_linux_arm.tar.gz task_checksums.txt
  check_example task.sh 3.53.1 windows amd64 \
    task_windows_amd64.zip task_checksums.txt
}

# every example must assemble into a script that parses
test_examples_assemble() {
  if [ ! -f ./dist/install-base.sh ]; then
    assert_skip "dist/install-base.sh not built - run 'make dist'"
    return 0
  fi
  d=$(mktmpdir)
  for cfg in ./install/examples/*.sh; do
    name=${cfg##*/}
    cat "$cfg" ./dist/install-base.sh >"$d/install.sh"
    assertTrue "sh -n '$d/install.sh'" "example $name: assembled script parses"
  done
  rm -rf "$d"
}

# golangci/golangci-lint v2.13.1 -- hyphens, zip on windows, and 27 platforms
# including the illumos/loong64/riscv64 entries
test_example_golangci() {
  check_example golangci-lint.sh 2.13.1 darwin arm64 \
    golangci-lint-2.13.1-darwin-arm64.tar.gz golangci-lint-2.13.1-checksums.txt
  check_example golangci-lint.sh 2.13.1 windows amd64 \
    golangci-lint-2.13.1-windows-amd64.zip golangci-lint-2.13.1-checksums.txt
  check_example golangci-lint.sh 2.13.1 illumos amd64 \
    golangci-lint-2.13.1-illumos-amd64.tar.gz golangci-lint-2.13.1-checksums.txt
  check_example golangci-lint.sh 2.13.1 linux loong64 \
    golangci-lint-2.13.1-linux-loong64.tar.gz golangci-lint-2.13.1-checksums.txt
}

# koalaman/shellcheck v0.11.0 -- a non-Go project: raw kernel arch spellings,
# the tag rather than the version, dot separators, and a windows zip shaped
# unlike every other asset
test_example_shellcheck() {
  check_example_path shellcheck.sh v0.11.0 darwin arm64 \
    shellcheck-v0.11.0.darwin.aarch64.tar.gz shellcheck-v0.11.0/shellcheck
  check_example_path shellcheck.sh v0.11.0 linux amd64 \
    shellcheck-v0.11.0.linux.x86_64.tar.gz shellcheck-v0.11.0/shellcheck
  check_example_path shellcheck.sh v0.11.0 linux armv6 \
    shellcheck-v0.11.0.linux.armv6hf.tar.gz shellcheck-v0.11.0/shellcheck
  # riscv64 is not remapped -- the project and uname_arch agree on that one
  check_example_path shellcheck.sh v0.11.0 linux riscv64 \
    shellcheck-v0.11.0.linux.riscv64.tar.gz shellcheck-v0.11.0/shellcheck
  # the windows zip carries no os/arch, and the exe sits at the root
  check_example_path shellcheck.sh v0.11.0 windows amd64 \
    shellcheck-v0.11.0.zip shellcheck.exe
}

# hadolint/hadolint v2.15.1 -- no archive at all, and a windows .exe that is a
# suffix without being an archive
test_example_hadolint() {
  check_example_path hadolint.sh v2.15.1 linux amd64 \
    hadolint-linux-x86_64 hadolint-linux-x86_64
  # arm64 passes through: hadolint uses the raw x86_64 but Go's arm64
  check_example_path hadolint.sh v2.15.1 linux arm64 \
    hadolint-linux-arm64 hadolint-linux-arm64
  check_example_path hadolint.sh v2.15.1 darwin arm64 \
    hadolint-macos-arm64 hadolint-macos-arm64
  # FORMAT=exe: a non-empty suffix, still not an archive
  check_example_path hadolint.sh v2.15.1 windows amd64 \
    hadolint-windows-x86_64.exe hadolint-windows-x86_64.exe
}

# gohugoio/hugo v0.165.0 -- BSDs, Solaris, and build variants
test_example_hugo() {
  check_example hugo.sh 0.165.0 linux amd64 \
    hugo_0.165.0_linux-amd64.tar.gz hugo_0.165.0_checksums.txt
  check_example hugo.sh 0.165.0 windows amd64 \
    hugo_0.165.0_windows-amd64.zip hugo_0.165.0_checksums.txt
  # the BSD family and Solaris, which no other example covers
  check_example hugo.sh 0.165.0 netbsd amd64 \
    hugo_0.165.0_netbsd-amd64.tar.gz hugo_0.165.0_checksums.txt
  check_example hugo.sh 0.165.0 openbsd amd64 \
    hugo_0.165.0_openbsd-amd64.tar.gz hugo_0.165.0_checksums.txt
  check_example hugo.sh 0.165.0 dragonfly amd64 \
    hugo_0.165.0_dragonfly-amd64.tar.gz hugo_0.165.0_checksums.txt
  check_example hugo.sh 0.165.0 solaris amd64 \
    hugo_0.165.0_solaris-amd64.tar.gz hugo_0.165.0_checksums.txt
  # armv7 folds to the single "arm" build
  check_example hugo.sh 0.165.0 linux armv7 \
    hugo_0.165.0_linux-arm.tar.gz hugo_0.165.0_checksums.txt
  # hugo publishes no illumos asset; adjust_os folds it onto the solaris
  # build.  That the resulting binary actually RUNS on illumos is not
  # provable here -- the OmniOS CI leg installs and executes it.
  check_example hugo.sh 0.165.0 illumos amd64 \
    hugo_0.165.0_solaris-amd64.tar.gz hugo_0.165.0_checksums.txt
}

# a variant is neither OS nor arch; archive_name being a shell function means
# it needs no new config concept
test_example_hugo_variant() {
  got=$(sh -c '. ./install/examples/hugo.sh
    . ./dist/shlib.min.sh
    . ./install/runner.sh
    VERSION=0.165.0; OS=linux; ARCH=arm64; HUGO_VARIANT=_extended
    adjust_format; adjust_os; adjust_arch
    echo "$(archive_name).${FORMAT}"')
  assertEquals "hugo_extended_0.165.0_linux-arm64.tar.gz" "$got" \
    "example hugo.sh: HUGO_VARIANT selects the extended build"
}

# Hugo publishes ONE linux-arm build and it is GOARM=7 (confirmed with
# `go version -m` on the 0.165.0 asset).  A GOARM=7 binary dies with SIGILL on
# ARMv6 hardware, so armv6 must be refused up front rather than installed and
# left to fail at run time.
test_example_hugo_no_armv6() {
  got=$(sh -c '. ./install/examples/hugo.sh
    . ./dist/shlib.min.sh
    . ./install/runner.sh
    PLATFORM=linux/armv6
    normalize_platforms
    check_platform 2>&1 >/dev/null' | head -1)
  case "$got" in
    *"no binary published for linux/armv6"*)
      assertTrue "true" "example hugo.sh: armv6 refused (the arm build is GOARM=7)"
      ;;
    *)
      assertTrue "false" "example hugo.sh: armv6 was not refused [$got]"
      ;;
  esac

  # armv7 is the one that must still work
  got=$(sh -c '. ./install/examples/hugo.sh
    . ./dist/shlib.min.sh
    . ./install/runner.sh
    PLATFORM=linux/armv7
    normalize_platforms
    check_platform >/dev/null 2>&1; echo $?')
  assertEquals "0" "$got" "example hugo.sh: armv7 is still accepted"
}

# The variant builds cover far fewer platforms than the plain build, so
# PLATFORMS is computed from HUGO_VARIANT.  Without that, an extended install
# on FreeBSD passes check_platform and then 404s.
test_example_hugo_variant_platforms() {
  got=$(sh -c 'HUGO_VARIANT=_extended
    . ./install/examples/hugo.sh
    . ./dist/shlib.min.sh
    . ./install/runner.sh
    PLATFORM=freebsd/amd64
    normalize_platforms
    check_platform 2>&1 >/dev/null' | head -1)
  case "$got" in
    *"no binary published for freebsd/amd64"*)
      assertTrue "true" "example hugo.sh: extended build refused on freebsd"
      ;;
    *)
      assertTrue "false" "example hugo.sh: extended freebsd was not refused [$got]"
      ;;
  esac

  # freebsd IS published for the plain build, so it must still pass there
  got=$(sh -c '. ./install/examples/hugo.sh
    . ./dist/shlib.min.sh
    . ./install/runner.sh
    PLATFORM=freebsd/amd64
    normalize_platforms
    check_platform >/dev/null 2>&1; echo $?')
  assertEquals "0" "$got" "example hugo.sh: plain build still accepted on freebsd"

  # and the three platforms that do have variant builds must pass
  for p in linux/amd64 linux/arm64 windows/amd64; do
    got=$(sh -c 'HUGO_VARIANT=_extended_withdeploy
      . ./install/examples/hugo.sh
      . ./dist/shlib.min.sh
      . ./install/runner.sh
      PLATFORM='"$p"'
      normalize_platforms
      check_platform >/dev/null 2>&1; echo $?')
    assertEquals "0" "$got" "example hugo.sh: variant build accepted on $p"
  done
}

# illumos must reach check_platform under its own name -- check_platform runs
# before adjust_os, so listing only solaris/amd64 would refuse it.
test_example_hugo_illumos_accepted() {
  got=$(sh -c '. ./install/examples/hugo.sh
    . ./dist/shlib.min.sh
    . ./install/runner.sh
    PLATFORM=illumos/amd64
    normalize_platforms
    check_platform >/dev/null 2>&1; echo $?')
  assertEquals "0" "$got" "example hugo.sh: illumos/amd64 is accepted"
}

# hugo publishes macOS as a .pkg only, so darwin must be refused rather than
# producing a 404 on a tarball that never existed
test_example_hugo_no_darwin() {
  got=$(sh -c '. ./install/examples/hugo.sh
    . ./dist/shlib.min.sh
    . ./install/runner.sh
    PLATFORM=darwin/arm64
    normalize_platforms
    check_platform 2>&1 >/dev/null' | head -1)
  case "$got" in
    *"no binary published for darwin/arm64"*)
      assertTrue "true" "example hugo.sh: darwin is refused with a real message"
      ;;
    *)
      assertTrue "false" "example hugo.sh: unexpected darwin message [$got]"
      ;;
  esac
}

test_example_gosec
test_example_hydra
test_example_task
test_example_golangci
test_example_shellcheck
test_example_hadolint
test_example_hugo
test_example_hugo_variant
test_example_hugo_no_darwin
test_example_hugo_no_armv6
test_example_hugo_illumos_accepted
test_example_hugo_variant_platforms
test_examples_assemble
# archives that wrap their contents in a directory, e.g.
#   golangci-lint-2.13.1-darwin-arm64/golangci-lint
# This was the only human-authored fix in the maintained godownloader fork.
test_execute_nested_binary() {
  workdir=$(mktmpdir)
  BINDIR="$workdir/bin"
  BINARY=testbin
  BINARIES=""
  NAME=testbin-1.2.3-linux-amd64
  TARBALL=$NAME.tar.gz
  TARBALL_URL=https://example.invalid/$TARBALL
  CHECKSUM=""
  OS=linux

  binary_path() { echo "${NAME}/$1"; }
  untar() {
    mkdir -p "$NAME"
    echo '#!/bin/sh' >"$NAME/testbin"
    chmod +x "$NAME/testbin"
  }

  execute >/dev/null 2>&1
  assertEquals "0" "$?" "execute: installs a binary nested in a directory"
  assertTrue "[ -x '$workdir/bin/testbin' ]" "execute: nested binary lands in BINDIR under its own name"

  binary_path() { echo "$1"; }
  untar() {
    echo '#!/bin/sh' >testbin
    chmod +x testbin
  }
  rm -rf "$workdir"
}

# BINARIES must iterate correctly; zsh does not word-split unquoted parameters
test_execute_multiple_binaries() {
  workdir=$(mktmpdir)
  BINDIR="$workdir/bin"
  BINARY=solo
  BINARIES="alpha beta"
  TARBALL=t.tar.gz
  TARBALL_URL=https://example.invalid/$TARBALL
  CHECKSUM=""
  OS=linux

  untar() {
    echo '#!/bin/sh' >alpha
    echo '#!/bin/sh' >beta
    chmod +x alpha beta
  }

  execute >/dev/null 2>&1
  assertTrue "[ -x '$workdir/bin/alpha' ]" "execute: installs the first of several binaries"
  assertTrue "[ -x '$workdir/bin/beta' ]" "execute: installs the second of several binaries"

  BINARIES=""
  untar() {
    echo '#!/bin/sh' >testbin
    chmod +x testbin
  }
  rm -rf "$workdir"
}

test_assembled_script
test_parse_args_defaults
test_parse_args_bindir
test_parse_args_tag
test_platform_supported
test_platform_unsupported
test_platform_message
test_platform_empty_skips
test_normalize_platforms
test_archive_name
test_adjust_defaults_are_noops
test_adjust_override_wins
test_tarball_name
test_unpack_default_is_untar
test_unpack_override_wins
test_execute
test_execute_verifies_checksum
test_execute_bad_checksum
test_execute_bare_binary
test_execute_nested_binary
test_execute_multiple_binaries
