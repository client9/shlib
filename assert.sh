
assertTrue() {
	eval $1
	if [ $? -ne 0 ]; then
	   echo "assertTrue failed: $2"
	   exit 2
        fi
}

assertFalse() {
	eval $1
	if [ $? -eq 0 ]; then
		echo "assertFalse failed: $2"
		exit 2
	fi
}

assertEquals() {
    want=$1
    got=$2
    msg=$3
    if [ "$want" != "$got" ]; then
        echo "assertEquals failed: want=$want got=$got $3"
        exit 2
    fi
}
