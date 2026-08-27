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

http_download() { echo stub >"$1"; }

untar() {
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
    echo "$(archive_name).${FORMAT} $(checksum_name)"')
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

test_example_gosec
test_example_hydra
test_example_task
test_example_golangci
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
test_execute
test_execute_verifies_checksum
test_execute_bad_checksum
test_execute_nested_binary
test_execute_multiple_binaries
