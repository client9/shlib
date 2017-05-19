
test:
	/bin/sh *_test.sh

lint:
	shellcheck -f gcc -s sh *.sh
	shellcheck -f gcc -s bash *.sh
	shellcheck -f gcc -s dash *.sh
	shellcheck -f gcc -s ksh *.sh

clean:
	git gc --aggressive

