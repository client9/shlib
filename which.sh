#/bin/sh
#
# which: returns true if command exists
# 
# Oddly `which` is not portable, in particular is often
# not available on RedHat/CentOS systems.
# 
# `type` is portable, but spews junk to both stdout and stderr
#
which() {
  type $1 > /dev/null 2> /dev/null
}

