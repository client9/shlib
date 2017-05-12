#
# http_download [local-file] [url] [optional extra header]
#
# if arg3 is not empty it will add it as an extra HTTP header
# must be in the form "foo: bar"
#
http_download() {
  DEST=$1
  SOURCE=$2
  HEADER=$3

  if is_command curl; then
    WGET="curl --fail -sSL"
    test -z "${HEADER}" || WGET="${WGET} -H \"${HEADER}\""
    if [ "${DEST}" != "-" ]; then
      WGET="$WGET -o $DEST"
    fi
  elif is_command wget &> /dev/null; then
    WGET="wget -q -O $DEST"
    test -z "${HEADER}" || WGET="${WGET} --header \"${HEADER}\""
  else
    echo "Unable to find wget or curl.  Exit"
    exit 1
  fi

  # remove destination if not stdout
  if [ "${DEST}" != "-" ]; then
    rm -f "${DEST}"
  fi

  # run
  ${WGET} ${SOURCE}
}
