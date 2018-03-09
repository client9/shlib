# function to prefix each log output
#  over-ride to add custom output or format
#
# by default prints the script name ($0)
log_prefix() {
  echo "$0"
}

# default priority
_logp=6

# set the log priority
#  todo: fancy turn string into number
log_set_priority() {
  _logp="$1"
}

# if no args, return the priority
# if arg, then test if greater than or equals to priority
log_priority() {
  if test -z "$1"; then
    echo "$_logp"
    return
  fi
  [ "$1" -le "$_logp" ]
}

log_tag() {
  case $1 in
    0) echo "emerg" ;;
    1) echo "alert" ;;
    2) echo "crit" ;;
    3) echo "err" ;;
    4) echo "warning" ;;
    5) echo "notice" ;;
    6) echo "info" ;;
    7) echo "debug" ;;
    *) echo "$1" ;;
  esac
}

log_debug() {
  log_priority 7 && echoerr "$(log_prefix)" "$(log_tag 7)" "$@"
}

log_info() {
  log_priority 6 && echoerr "$(log_prefix)" "$(log_tag 6)" "$@"
}

log_err() {
  log_priority 3 && echoerr "$(log_prefix)" "$(log_tag 3)" "$@"
}

# log_crit is for platform problems
log_crit() {
  log_priority 2 && echoerr "$(log_prefix)" "$(log_tag 2)" "$@"
}
