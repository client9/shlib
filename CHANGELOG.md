# Changelog

Versions are [CalVer](https://calver.org/) — the date of the release. The API
shape rarely changes, so SemVer's compatibility signal would buy little, while
a date makes a stale embedded copy obvious on sight.

If you are running an embedded copy, the version is in its preamble:

```sh
sed -n 's/^shlib \(.*\)/\1/p' your-install.sh
```

## Unreleased

Rename this heading to the release date when cutting a release — see
[docs/RELEASING.md](docs/RELEASING.md).

### Fixed

- **The minifier silently dropped code.** The documented strip pipeline
  (`grep -v '^#' | grep -v ' #'`) also deleted *code lines carrying trailing
  comments*. In the `2026.08.27` bundle that removed the `win*) os="windows"`
  mapping — so `Windows_NT` resolved to `windows_nt`, not a GOOS — and both
  `gitrepo=` assignments from `git_clone_or_update`. Now only whole-line
  comments are stripped. **Anyone who vendored `2026.08.27` should re-vendor.**
- `http_download` had no `fetch` branch, so it failed outright on stock
  FreeBSD, which ships neither curl nor wget. `github_release` and the whole
  installer were unusable there.
- `github_release` returned whatever its `sed` found, so a non-GitHub host or
  an error page yielded a garbage tag (`<!DOCTYPE html> <html lang=`) and a
  baffling 404 later. The result is now validated.
- `mktmpdir` trusted `mktemp`'s default mode. `mktemp` is not in POSIX and
  git-bash creates `0755`; the mode is now set explicitly.
- Internal variables leaked into the caller's shell. Calling `github_release`
  overwrote `$version`, `uname_os` overwrote `$os`, and 26 more. All internals
  are now prefixed `_shlib_`.

### Added

- **`install/`** — a replacement for the archived
  [godownloader](https://github.com/goreleaser/godownloader). An install script
  is `config.sh` + `dist/install-base.sh` concatenated: no Go, no YAML, no
  template language. See [docs/INSTALLERS.md](docs/INSTALLERS.md) and five
  worked [examples](install/examples/).
- `http_download_fetch`, for FreeBSD. Note `fetch(1)` cannot send arbitrary
  headers; `Accept` is mapped via `HTTP_ACCEPT` and anything else fails
  loudly rather than being silently dropped.
- **[docs/API.md](docs/API.md)** — a generated index of every function, plus
  the recognised GOOS/GOARCH values and the non-obvious `uname` mappings
  (including `SunOS` → `illumos`/`solaris`). `make docs` regenerates it and CI
  fails if it drifts.
- Solaris and illumos CI (`vmactions/solaris-vm`, `vmactions/omnios-vm`),
  running the `SunOS` → `solaris`/`illumos` branch on real systems. That branch
  has caused more bugs than any other mapping here and had only ever been
  tested with a stubbed `uname`.
- Windows CI (git-bash and MSYS2), verifying that `MINGW64_NT-*` and
  `MSYS_NT-*` really do map to `windows` — previously only ever tested with a
  stubbed `uname`.
- `.gitattributes`, pinning the tree to LF and marking `fixtures/**` as
  binary. Without it Windows checks fixtures out as CRLF and every hash test
  fails with a digest that looks arbitrary.
- A pre-commit hook (`make hooks`) running the fast, offline half of CI.
- `DOWNLOAD_BASE` and `latest_version()` hooks, so an installer can fetch from
  somewhere other than GitHub. Defaults are unchanged.
- Tests for `log.sh` (35 assertions) and the `fetch` branch.

### Changed

- Error messages no longer end with "Please file bug at
  github.com/client9/shlib". Roughly 812 stale copies carry that line and send
  their bugs here — usually for problems fixed years earlier. Install-script
  authors should surface their own support URL.
- Assertions hold back stderr and print it only on failure. A passing run was
  emitting 25 lines of expected noise, which buried real failures.
- `actions/checkout` v4 → v7 (the v4 Node 20 runtime is deprecated).

## 2026.08.27

The first tagged release. shlib had been consumed by copy-and-paste since 2017,
which is the problem this release exists to address: bugs fixed here never
reached the copies. Roughly 920 vendored copies are in the wild; about 258 still
lack a Windows fix from 2018.

**This bundle has a known defect** — see the minifier bug under Unreleased.
Prefer the next release.

### Added

- Versioned, downloadable bundles: `dist/shlib.sh` (commented),
  `dist/shlib.min.sh` (stripped) and `checksums.txt`, committed to the repo and
  attached to each release. Each carries its version in the preamble, so a bug
  report can be dated at a glance.
- GitHub Actions replacing the dead Travis config, covering 13 shells across
  Linux (glibc), Alpine (musl), macOS and FreeBSD.
- A test suite that actually exercises the mapping tables: `uname` is stubbed,
  so every branch runs on every machine rather than only the host's.
- `untar` support for `.tar.bz2`, `.tar.xz` and `.tar.zst`. Note busybox `tar`
  has no `--zstd`, so that path decompresses through a pipe.
- `riscv64` and `loong64` architectures; `aix`, `ios`, `js` and `wasip1`
  operating systems.
- Documentation on [embedding](docs/EMBEDDING.md) and
  [releasing](docs/RELEASING.md).

### Fixed

- `hash_sha256_verify` / `hash_sha512_verify` matched the filename with an
  unanchored `grep`, treating it as a regular expression. A checksum listed for
  `evil-foo.tgz` would verify `foo.tgz`. Now an exact field match, and
  duplicate entries are refused rather than silently resolved.
- The `openssl` fallback in `hash_sha256` and `hash_sha512` had never worked —
  it ran `openssl -dst openssl dgst` and then `cut -f a`, an illegal field
  spec.
- `uname_os` used `==` inside `[ ]`, a bashism. Under any POSIX shell the
  illumos check silently fell through to `solaris`.
- The hash functions passed `/dev/stdin` as a filename. ksh93 implements
  pipelines with socketpairs, so that path cannot be opened and every
  stdin-based hash failed there.
- `mktmpdir` returned the shared `$TMPDIR` whenever it was set — always, on
  macOS and in most CI — so callers shared one predictable directory.
- `http_copy` leaked its temporary file on the failure path and round-tripped
  the body through a variable, stripping trailing newlines.

### Changed

- The test harness reports all failures instead of aborting at the first one.
