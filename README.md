# shlib
portable shell functions for `curl | sh` installers

[![lint](https://github.com/client9/shlib/actions/workflows/lint.yml/badge.svg?branch=master)](https://github.com/client9/shlib/actions/workflows/lint.yml)
[![linux](https://github.com/client9/shlib/actions/workflows/linux.yml/badge.svg?branch=master)](https://github.com/client9/shlib/actions/workflows/linux.yml)
[![macos](https://github.com/client9/shlib/actions/workflows/macos.yml/badge.svg?branch=master)](https://github.com/client9/shlib/actions/workflows/macos.yml)
[![freebsd](https://github.com/client9/shlib/actions/workflows/freebsd.yml/badge.svg?branch=master)](https://github.com/client9/shlib/actions/workflows/freebsd.yml)
[![openbsd](https://github.com/client9/shlib/actions/workflows/openbsd.yml/badge.svg?branch=master)](https://github.com/client9/shlib/actions/workflows/openbsd.yml)
[![netbsd](https://github.com/client9/shlib/actions/workflows/netbsd.yml/badge.svg?branch=master)](https://github.com/client9/shlib/actions/workflows/netbsd.yml)
[![dragonflybsd](https://github.com/client9/shlib/actions/workflows/dragonflybsd.yml/badge.svg?branch=master)](https://github.com/client9/shlib/actions/workflows/dragonflybsd.yml)
[![sunos](https://github.com/client9/shlib/actions/workflows/sunos.yml/badge.svg?branch=master)](https://github.com/client9/shlib/actions/workflows/sunos.yml)
[![alpine](https://github.com/client9/shlib/actions/workflows/alpine.yml/badge.svg?branch=master)](https://github.com/client9/shlib/actions/workflows/alpine.yml)
[![windows](https://github.com/client9/shlib/actions/workflows/windows.yml/badge.svg?branch=master)](https://github.com/client9/shlib/actions/workflows/windows.yml)
[![python](https://github.com/client9/shlib/actions/workflows/python.yml/badge.svg?branch=master)](https://github.com/client9/shlib/actions/workflows/python.yml)

You publish binaries on GitHub Releases and want your users to run one line:

```sh
curl -sSfL https://raw.githubusercontent.com/OWNER/REPO/master/install.sh | sh -s -- -b /usr/local/bin
```

**shlib generates that `install.sh`.** It is the replacement for the archived
[godownloader][gd] — with no Go, no YAML and no template language, because a
shell function is already a lazily-evaluated template.

[gd]: https://github.com/goreleaser/godownloader

The generated script detects the platform, resolves `latest` or a pinned tag,
downloads the right asset, verifies its SHA-256 against your checksums file,
unpacks it, and installs the binary — on everything in the
[test matrix](#tested-where-it-actually-has-to-run), down to Solaris, the BSDs
and git bash.

## Build an installer

An install script is two files concatenated:

```
config.sh              yours, ~12 lines
dist/install-base.sh   ours: the shlib functions + the installer flow
```

Your config only *describes* your release naming. This is
[`install/examples/gosec.sh`](install/examples/gosec.sh) with its comments
trimmed — the values are exact, and nothing else is needed:

```sh
OWNER=securego
REPO=gosec
BINARY=gosec
FORMAT=tar.gz
BINDIR=${BINDIR:-./bin}

# your build matrix -- you already know it.  Declaring it lets the installer
# say "no binary for windows/arm64" instead of failing with a bare 404.
PLATFORMS="darwin/amd64 darwin/arm64
           linux/amd64 linux/arm64 linux/ppc64le linux/s390x
           windows/amd64 windows/arm64"

archive_name()  { echo "${BINARY}_${VERSION}_${OS}_${ARCH}"; }
checksum_name() { echo "${BINARY}_${VERSION}_checksums.txt"; }
```

Build it — `cat` is the generator:

```sh
curl -sSfL -o /tmp/base.sh \
  https://raw.githubusercontent.com/client9/shlib/master/dist/install-base.sh
cat config.sh /tmp/base.sh > install.sh
```

Commit `install.sh`, and your users get:

```sh
sh install.sh                 # latest release, into ./bin
sh install.sh -b /usr/local/bin
sh install.sh -b ./bin v2.22.0   # a specific tag
```

Your config comes first because it only *defines* things; the flow runs at the
very end of `install-base.sh`, so a `curl | sh` truncated mid-transfer either
does nothing or fails to parse — it cannot half-install.

### If your filenames are unusual

Everything is an ordinary shell function, so anything a template language could
express you can just write:

```sh
adjust_format() { case ${OS} in windows) FORMAT=zip ;; esac; }
adjust_os()     { case ${OS} in darwin) OS=macOS ;; esac; }
adjust_arch()   { case ${ARCH} in amd64) ARCH=x86_64 ;; esac; }
binary_path()   { echo "${NAME}/$1"; }   # binary nested inside the archive
unpack()        { :; }                   # the asset IS the binary, no archive
```

### Worked examples

Seven real projects, each with a different naming scheme, each tested against
that project's actual published asset names:

| example | what it shows |
| ------- | ------------- |
| [`gosec.sh`](install/examples/gosec.sh) | the simple case — no hooks at all |
| [`hydra.sh`](install/examples/hydra.sh) | renamed OS and arch, `.zip` on windows |
| [`task.sh`](install/examples/task.sh) | no version in the archive name |
| [`golangci-lint.sh`](install/examples/golangci-lint.sh) | 27 platforms, binary nested in a versioned directory |
| [`hugo.sh`](install/examples/hugo.sh) | BSDs, Solaris, illumos, and build variants |
| [`shellcheck.sh`](install/examples/shellcheck.sh) | not a Go project — raw `x86_64`/`aarch64` names |
| [`hadolint.sh`](install/examples/hadolint.sh) | no archive at all — the asset is the binary |

Full guide: **[docs/INSTALLERS.md](docs/INSTALLERS.md)**.

## The building blocks

The installer is assembled from a library of standalone functions, and you can
use them directly — for a build script, a bootstrap, a CI step. Each lives in
its own `<name>.sh` and is meant to be **concatenated into your script**, not
sourced as a dependency: a `curl | sh` installer cannot have dependencies, so
the code has to travel with it.

`uname_os` `uname_arch` `http_download` `hash_sha256_verify` `untar`
`install_exe` `mktmpdir` `github_release` `log_*` — 33 in total, indexed in
[docs/API.md](docs/API.md).

Pre-built bundles are committed here and attached to every release:

| file | what it is |
| ---- | ---------- |
| [`dist/install-base.sh`](dist/install-base.sh) | shlib + installer logic; prepend your config |
| [`dist/shlib.sh`](dist/shlib.sh) | just the functions |

```sh
curl -sSfL -o vendor/shlib.sh \
  https://raw.githubusercontent.com/client9/shlib/master/dist/shlib.sh
```

**Fetch a bundle at build time rather than pasting a copy that goes stale** —
[docs/EMBEDDING.md](docs/EMBEDDING.md) explains why that matters more than it
sounds like it should.

Or build a custom subset — `cat` is the whole build step. List the files in
dependency order; most functions report errors through `log_err` / `log_crit`,
so include `echoerr.sh` and `log.sh` whenever you include something that can
fail:

```sh
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
  license_end.sh > vendor/shlib.sh
```

Nothing is stripped or minified, here or in `dist/`. shlib used to publish a
comment-stripped bundle; it saved about 10 KB gzipped and once shipped a
release with valid checksums and missing code, so it is gone. Comments also
make a `curl | sh` script something a cautious user can actually read.

## Tested where it actually has to run

Every push runs the whole suite — not a subset — against each shell below. A
GitHub Actions badge covers a whole workflow, so the badges above are grouped
by platform; per-shell results are in the Actions tab. The BSDs and Solaris run
in QEMU VMs, since GitHub provides no runner for any of them.

| platform        | shells tested                                        |
| --------------- | ---------------------------------------------------- |
| Linux (glibc)   | `dash` `bash` `ksh93` `mksh` `yash` `posh` `busybox ash` |
| Alpine (musl)   | `busybox ash`                                        |
| macOS           | `sh` `bash 3.2` `ksh` `zsh` `dash`                   |
| FreeBSD 14, 15  | `sh` `dash` `bash` `ksh93` `mksh` `yash` `zsh`       |
| OpenBSD 7.9, 7.8 | `sh` (OpenBSD ksh)                                  |
| NetBSD 11.0, 10.1 | `sh` `ksh`                                          |
| DragonFly 6.4   | `sh`                                                 |
| Solaris 11.4, OmniOS | `sh`                                             |
| Windows         | `git bash` `msys2`                                   |
| `python:3-slim` | `sh` — no curl, wget, fetch or ftp at all            |

Several legs also assert something the suite alone cannot:

- Solaris and OmniOS, that `SunOS` resolves to `solaris` and `illumos`
  respectively -- both systems report that ancient name, and telling them
  apart has been the most bug-prone mapping in this library.
- FreeBSD, OpenBSD, NetBSD and DragonFly, that curl and wget really are
  absent. They are the only legs that exercise `http_download`'s `fetch(1)`
  and `ftp(1)` branches, and a dependency quietly installing curl would stop
  that without anything going red.
- OmniOS builds a real installer from `install/examples/hugo.sh`, runs it, and
  executes the downloaded binary.
- `python:3-slim` asserts that no downloader is installed at all, then runs
  the whole suite and a real install through `http_download_python`. Container
  images routinely ship a language runtime and nothing else.

The library **recognises** a wider set than it can practically test: 17
operating systems and 16 architectures. See
[Platforms](docs/API.md#platforms) for the generated lists.

```sh
make test                      # everything under /bin/sh
make test TEST_SHELL=dash      # ... under one specific shell
make test-all                  # ... under every shell installed locally
make lint                      # shellcheck (sh, bash, dash, ksh) + shfmt
```

## Documentation

| document | what it covers |
| -------- | -------------- |
| [docs/INSTALLERS.md](docs/INSTALLERS.md) | building a `curl \| sh` installer |
| [docs/API.md](docs/API.md) | generated index of all 33 functions |
| [docs/EMBEDDING.md](docs/EMBEDDING.md) | vendoring shlib without going stale |
| [docs/PORTABILITY.md](docs/PORTABILITY.md) | which shells break which idiom, which systems ship pre-POSIX tools |
| [docs/RELEASING.md](docs/RELEASING.md) | cutting a release |
| [CONTRIBUTING.md](CONTRIBUTING.md) | changing shlib itself |
| [CHANGELOG.md](CHANGELOG.md) | what changed |

## Why this exists

I've sadly written a lot of shell scripts.   Mostly for installers on
completely alien environments.

Really shell code should only be used for boot-strapping to something sane.  Until then you might need some truly portable functions.  I hope you never need to use them, but if you do they are [public domain](http://unlicense.org).  Do whatever you'd like with them.

However acknowledgement (and pull requests) are appreciated.  You can optionally include [license.sh](license.sh) so the next person knows where to find them.
