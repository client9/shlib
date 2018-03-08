# date_iso8601 returns a ISO 8601 UTC formatted date
#
# https://en.wikipedia.org/wiki/ISO_8601
#
date_iso8601() {
	date -u +%Y-%m-%dT%H:%M:%S+0000
}
