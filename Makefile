# Shell used to run the *_test.sh files.  Override to test portability:
#   make test TEST_SHELL=dash
#   make test TEST_SHELL="busybox sh"
TEST_SHELL ?= /bin/sh

# Which test files to run.  Override to run one: make test TESTS=hash_md5_test.sh
TESTS ?= *_test.sh

# Linters.  Override if they live somewhere other than PATH / ./bin
SHELLCHECK ?= shellcheck
SHFMT      ?= ./bin/shfmt

test: ## run tests (TEST_SHELL=dash, TESTS=hash_sha256_test.sh)
	@echo "== $@: shell '$(TEST_SHELL)' =="
	@err=0; n=0; \
	for t in $(TESTS); do \
	  n=$$((n + 1)); \
	  $(TEST_SHELL) $$t || err=1; \
	done; \
	if [ $$err -eq 0 ]; then echo "== $$n test files ok =="; else echo "== FAILURES (see above) =="; fi; \
	exit $$err

test-all: ## run tests under every POSIX-ish shell found on this machine
	@err=0; \
	for s in sh dash bash ksh ksh93 mksh yash zsh "busybox sh"; do \
	  c=$${s%% *}; \
	  command -v "$$c" >/dev/null 2>&1 || { printf '%-14s -- not installed\n' "$$s"; continue; }; \
	  if $(MAKE) --no-print-directory test TEST_SHELL="$$s" >/dev/null 2>&1; then \
	    printf '%-14s PASS\n' "$$s"; \
	  else \
	    printf '%-14s FAIL\n' "$$s"; err=1; \
	  fi; \
	done; exit $$err

lint: $(SHFMT) ## run shellcheck and check formatting
	@SHELLCHECK='$(SHELLCHECK)' SHFMT='$(SHFMT)' ./scripts/lint.sh

fmt: $(SHFMT) ## reformat shell scripts
	$(SHFMT) -ci -p -i 2 -w *.sh scripts/*.sh install/*.sh

dist: ## rebuild the concatenated bundles in ./dist
	./scripts/dist.sh

tools: ## download pinned shellcheck + shfmt into ./bin
	./scripts/install-tools.sh

clean: ## clean up
	rm -rf ./bin

./bin/shfmt:
	./scripts/install-tools.sh

# https://www.client9.com/self-documenting-makefiles/
help:
	@awk -F ':|##' '/^[^\t].+?:.*?##/ {\
	printf "\033[36m%-30s\033[0m %s\n", $$1, $$NF \
	}' $(MAKEFILE_LIST)

.DEFAULT_GOAL = help
.PHONY: help test test-all lint fmt dist tools clean
