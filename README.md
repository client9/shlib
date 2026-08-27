# shlib
portable functions for posix shell environments

[![lint](https://github.com/client9/shlib/actions/workflows/lint.yml/badge.svg?branch=master)](https://github.com/client9/shlib/actions/workflows/lint.yml)
[![linux](https://github.com/client9/shlib/actions/workflows/linux.yml/badge.svg?branch=master)](https://github.com/client9/shlib/actions/workflows/linux.yml)
[![macos](https://github.com/client9/shlib/actions/workflows/macos.yml/badge.svg?branch=master)](https://github.com/client9/shlib/actions/workflows/macos.yml)
[![freebsd](https://github.com/client9/shlib/actions/workflows/freebsd.yml/badge.svg?branch=master)](https://github.com/client9/shlib/actions/workflows/freebsd.yml)
[![alpine](https://github.com/client9/shlib/actions/workflows/alpine.yml/badge.svg?branch=master)](https://github.com/client9/shlib/actions/workflows/alpine.yml)

Every push is tested against each shell below.  A GitHub Actions badge covers
a whole workflow, so the badges are grouped by platform; the per-shell result
for a given run is in the Actions tab.  FreeBSD runs in a QEMU VM, since
GitHub provides no FreeBSD runner.

| platform        | shells tested                                        |
| --------------- | ---------------------------------------------------- |
| Linux (glibc)   | `dash` `bash` `ksh93` `mksh` `yash` `posh` `busybox ash` |
| Alpine (musl)   | `busybox ash`                                        |
| macOS           | `sh` `bash 3.2` `ksh` `zsh` `dash`                   |
| FreeBSD 14, 15  | `sh` `dash` `bash` `ksh93` `mksh` `yash` `zsh`       |

I've sadly written a lot of shell scripts.   Mostly for installers on
completely alien environments.

Really shell code should only be used for boot-strapping to something sane.  Until then you might need some truly portable functions.  I hope you never need to use them, but if you do they are [public domain](http://unlicense.org).  Do whatever you'd like with them.

However acknowledgement (and pull requests) are appreciated.  You can optionally include [license.sh](license.sh) so the next person knows where to find them.

## Usage

**Embedding this in an install script?** Read
[docs/EMBEDDING.md](docs/EMBEDDING.md) — it explains how to pull a current
bundle at build time instead of vendoring a copy that goes stale.
Maintainers: see [docs/RELEASING.md](docs/RELEASING.md).

Pre-built bundles are committed to this repo and attached to every release:

| file | what it is |
| ---- | ---------- |
| [`dist/shlib.min.sh`](dist/shlib.min.sh) | all functions, comments stripped — embed this |
| [`dist/shlib.sh`](dist/shlib.sh) | all functions, comments intact |

```sh
curl -sSfL -o vendor/shlib.min.sh \
  https://raw.githubusercontent.com/client9/shlib/master/dist/shlib.min.sh
```

Or build a custom subset yourself.

Here's an example of how to create and compress a custom set of functions.  Using `grep -v '^#' | grep -v ' #' | tr -s '\n'` strips away comments and blank lines.

List the files in dependency order.  Most functions report errors through
`log_err` / `log_crit`, so include `echoerr.sh` and `log.sh` whenever you
include something that can fail.

```bash
cat \
  license.sh \
  is_command.sh \
  echoerr.sh \
  log.sh \
  uname_os.sh \
  uname_arch.sh \
  untar.sh \
  mktmpdir.sh \
  http_download.sh \
  hash_sha256.sh \
  license_end.sh | \
  grep -v '^#' | grep -v ' #' | tr -s '\n'
```

## WIP

Some of these are new, some are these are pulled from old code I wrote.   All can definitely be
improved.  Pull requests very welcome:

* Simplify
* Clean up local variable use

## Testing

The test harness is plain POSIX shell (see [assert.sh](assert.sh)); a test file
is just a shell script that sources the functions it exercises.  Assertions are
non-fatal, so one failure does not hide the rest of the file, and each file
prints a pass/fail total.

```bash
make test                      # run everything under /bin/sh
make test TEST_SHELL=dash      # ... under one specific shell
make test TESTS=untar_test.sh  # ... one file
make test-all                  # ... under every shell installed locally
make lint                      # shellcheck (sh, bash, dash, ksh) + shfmt
```

Functions that consult `uname` are tested with a stubbed `uname`, so the whole
mapping table is exercised on every machine rather than only the branch that
matches the host.

## Documentation

I've start to write doco in Markdown as shell comments.  The plan would be to extract it to standalone markdown so it would display on GitHub.

