
test:
	/bin/sh *_test.sh

lint:
	./scripts/lint.sh

fmt:
	./bin/shfmt -p -i 2 -w *.sh

clean:
	rm -rf ./bin
	git gc --aggressive

