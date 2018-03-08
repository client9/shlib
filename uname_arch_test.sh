. ./assert.sh
. ./echoerr.sh
. ./log.sh
. ./uname_arch.sh
. ./uname_arch_check.sh

# The self-check is the test.  If the conversion
# is done improperly it will fail.
uname_arch_check
