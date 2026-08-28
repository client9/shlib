. ./assert.sh
. ./echoerr.sh
. ./log.sh
. ./uname_arch.sh
. ./uname_arch_check.sh

# stub `uname -m` so the whole mapping table is exercised anywhere
stub_uname() {
  _stub_m=$1
  uname() { echo "$_stub_m"; }
}

unstub_uname() {
  unset -f uname 2>/dev/null
}

# check_arch <uname -m> <expected canonical name>
check_arch() {
  stub_uname "$1"
  got=$(uname_arch)
  unstub_uname
  assertEquals "$2" "$got" "uname_arch: '$1' => '$2'"
}

check_accepted() {
  stub_uname "$1"
  uname_arch_check >/dev/null 2>&1
  rc=$?
  unstub_uname
  assertEquals "0" "$rc" "uname_arch_check accepts the mapping of '$1'"
}

test_intel() {
  check_arch x86_64 amd64
  check_arch i86pc amd64
  check_arch x86 386
  check_arch i686 386
  check_arch i386 386
}

# arm 8 is arm64 / aarch64; arm 5,6,7 carry a trailing letter
# https://github.com/golang/go/wiki/GoArm
test_arm() {
  check_arch aarch64 arm64
  check_arch arm64 arm64
  check_arch armv5tel armv5
  check_arch armv6l armv6
  check_arch armv7l armv7
}

test_other() {
  check_arch ppc64 ppc64
  check_arch ppc64le ppc64le
  check_arch s390x s390x
  check_arch mips64 mips64
  check_arch riscv64 riscv64
  check_arch loongarch64 loong64
}

test_checker() {
  check_accepted x86_64
  check_accepted aarch64
  check_accepted armv7l
  check_accepted riscv64
  check_accepted loongarch64
  stub_uname NotAnArch
  uname_arch_check >/dev/null 2>&1
  rc=$?
  unstub_uname
  assertNotEquals "0" "$rc" "uname_arch_check rejects an unrecognized architecture name"
}

# the real machine must still self-check
test_selfcheck() {
  assertTrue "uname_arch_check" "uname_arch_check passes on this machine"
}

test_intel
test_arm
test_other
test_checker
test_selfcheck
