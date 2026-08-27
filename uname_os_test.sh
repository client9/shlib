. ./assert.sh
. ./echoerr.sh
. ./log.sh
. ./uname_os.sh
. ./uname_os_check.sh

# Stub `uname` so the mapping table is exercised on every machine, not just
# the one the tests happen to run on.  Without this the suite only ever saw
# one branch of the case statement, which is how the illumos branch shipped
# broken: `[ $(uname -o) == "illumos" ]` is a bashism that silently fell
# through to "solaris" under dash.
stub_uname() {
  _stub_s=$1
  _stub_o=$2
  uname() {
    case "$1" in
      -s) echo "$_stub_s" ;;
      -o)
        # a missing `uname -o` (Oracle Solaris, macOS) must be non-fatal
        test -n "$_stub_o" || return 1
        echo "$_stub_o"
        ;;
      *) echo "$_stub_s" ;;
    esac
  }
}

unstub_uname() {
  unset -f uname 2>/dev/null
}

# check_os <uname -s> <expected GOOS> [uname -o]
check_os() {
  stub_uname "$1" "$3"
  got=$(uname_os)
  unstub_uname
  assertEquals "$2" "$got" "uname_os: '$1' => '$2'"
}

# every value the mapper can emit must be accepted by the checker
check_accepted() {
  stub_uname "$1" "$2"
  uname_os_check >/dev/null 2>&1
  rc=$?
  unstub_uname
  assertEquals "0" "$rc" "uname_os_check accepts the mapping of '$1'"
}

test_unix() {
  check_os Linux linux
  check_os Darwin darwin
  check_os FreeBSD freebsd
  check_os NetBSD netbsd
  check_os OpenBSD openbsd
  check_os DragonFly dragonfly
  check_os AIX aix
  # MidnightBSD is a FreeBSD derivative; reported as a bug against a stale
  # vendored copy of this library that predated commit 7f68437 (2021-01-09).
  # See the note in uname_os_check.sh: midnightbsd is not actually a GOOS.
  check_os MidnightBSD midnightbsd
}

# https://github.com/client9/shlib/issues/3
test_windows() {
  check_os MINGW64_NT-10.0 windows
  # git-bash on Windows 10 appends the build number; reported as a bug
  # against a vendored copy that predated 56b1c04 (2018-12-10)
  check_os MINGW64_NT-10.0-19045 windows
  check_os MINGW32_NT-6.1 windows
  check_os MSYS_NT-10.0 windows
  check_os CYGWIN_NT-10.0 windows
  check_os Windows_NT windows
}

# SunOS reports the ancient name; -o distinguishes illumos from Solaris
test_sunos() {
  check_os SunOS illumos illumos
  check_os SunOS solaris         # no `uname -o` at all => Oracle Solaris
  check_os SunOS solaris Solaris # -o present but not illumos
}

test_checker() {
  check_accepted Linux
  check_accepted Darwin
  check_accepted MINGW64_NT-10.0
  check_accepted SunOS illumos
  check_accepted MidnightBSD
  check_accepted SunOS
  # the checker must reject something that is not a GOOS
  stub_uname NotAnOS
  uname_os_check >/dev/null 2>&1
  rc=$?
  unstub_uname
  assertNotEquals "0" "$rc" "uname_os_check rejects a non-GOOS value"
}

# and the real machine must still self-check
test_selfcheck() {
  assertTrue "uname_os_check" "uname_os_check passes on this machine"
}

test_unix
test_windows
test_sunos
test_checker
test_selfcheck
