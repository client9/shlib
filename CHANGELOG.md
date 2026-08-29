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

- **`unpack` collided with a real command on Solaris and illumos.** The hook
  guards asked `command -v NAME` and looked only at its exit status, which
  answers "does a command by this name exist", not "did the config define a
  function". Solaris and illumos ship `/usr/bin/unpack` (the companion to
  `pack`/`pcat`), so the guard found it, skipped defining the default, and
  every install on those systems ran `/usr/bin/unpack` instead of `untar`,
  failing with `unpack: <file>: cannot open`. The guards now compare
  `command -v`'s *output* to the name — it prints the bare name for a function
  or builtin and an absolute path for an external program. Applies to all six
  hooks and to `checksum_name` in `main.sh`.
- **The installer leaked its temp directory on every failure path.** `execute`
  removed it as its last statement, so all six `|| return 1` before that point
  left it behind — and a failed install is more likely to be retried than a
  successful one, so they accumulated in `TMPDIR`. The body is now
  `_shlib_execute` and `execute` cleans up around it, whatever the outcome.
  (Not an `EXIT` trap, which is the idiom `mktmpdir` documents: `assert.sh`
  installs its own `EXIT` trap to print test totals, and `execute` is called
  directly by the tests.)
- **A failed download reported only the downloader's own message.** `curl: (22)
  The requested URL returned error: 404` names neither the project nor the URL,
  and the installer then exited silently. It now says:

  ```
  owner/repo err unable to download https://github.com/owner/repo/releases/download/v1.2.3/asset.tar.gz
  ```

  which is the information needed when a tag or an `archive_name` does not
  match the real assets — the most common config mistake.

### Added

- **`unpack`, a hook for releases that are not archives.** `execute` called
  `untar` unconditionally, and `untar` refuses anything without a recognised
  archive suffix, so a project publishing bare binaries could not be installed
  at all. Configs now override:

  ```sh
  FORMAT=""
  unpack() { :; }
  binary_path() { echo "${TARBALL}"; }
  ```

  Existing configs are unaffected — the default is `untar "$1"`, defined behind
  the same `command -v` guard as `binary_path` and `latest_version`.

  Unpacking is a hook rather than a `FORMAT=binary` value because the two are
  independent: hadolint's windows asset is `hadolint-windows-x86_64.exe`, a
  non-empty suffix that is still not an archive, and one field cannot express
  both. `install/examples/hadolint.sh` is the worked example.
- `FORMAT` may now be empty. `TARBALL` is built by a new `tarball_name`
  function so the suffix is omitted rather than leaving a trailing dot, and so
  the construction can be unit tested — it previously lived inline in
  `main.sh`, which tests cannot source.

### Changed

- **Reframed what shlib says it is.** It described itself as "portable posix
  shell functions", which undersold it in both directions: POSIX describes
  neither where the code runs (Windows via git bash is not a POSIX
  environment; Solaris and illumos ship *pre*-POSIX tools) nor what it
  provides (install-script primitives — detect the platform, download, verify,
  unpack, place a binary). POSIX `sh` is the constraint that makes those
  travel, not the product. The preamble in `license.sh`, which ships in every
  vendored copy, now reads:

  ```
  https://github.com/client9/shlib - portable shell functions for install scripts
  ```

  The `POSIX sh only` coding rule is unchanged. Documentation also stopped
  claiming shlib "does not claim to run" on Windows, which contradicted a
  Windows CI leg that runs the full suite.
- **The platform names are documented as shlib's own, not Go's.** They still
  match GOOS/GOARCH — that is where the artifact-naming convention came from,
  and compatibility with it is deliberate — but Go is now provenance rather
  than authority. `docs/API.md` gains a *How a name gets added* section stating
  the rule (a real `uname` maps to it, and projects name artifacts that way),
  which is what the three long-standing deviations already follow:
  `midnightbsd`, `armv5`/`armv6`/`armv7`, and the retained `nacl`/`amd64p32`.
  No mapping, no accepted value, and no return value changed.
- The self-check error messages no longer say *GOOS* / *GOARCH*, which meant
  nothing to anyone installing a non-Go binary:

  ```
  uname_os_check 'Haiku' got converted to 'haiku' which is not a recognized OS name
  uname_arch_check 'sparc64' got converted to 'sparc64' which is not a recognized architecture name
  ```

  Anything matching on the old `not a GOOS value` text — the phrase is a useful
  fingerprint for stale vendored copies — should note that it now identifies a
  copy predating this release.

## 2026.08.28

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
- Same gap on OpenBSD and NetBSD, which ship neither curl, wget *nor* fetch.
  Their base downloader is `ftp(1)`, now a branch of its own — see below.
- **The library aborted under `set -u`.** Every optional argument was read as a
  bare `$2` / `$3`, which nounset treats as an error rather than an empty
  string, so `github_release owner/repo` (tag omitted — the documented form),
  `http_download file url` (no header), `hash_sha256` reading stdin, and
  `github_api` without `GITHUB_TOKEN` all killed the calling shell. The
  installer was worse: `curl … | sh` with no tag argument aborted in
  `parse_args` before anything was downloaded, and a config without
  `PLATFORMS` or `checksum_name` aborted too. An install script is exactly the
  kind of thing people run under `set -eu`. All optional parameters are now
  `${n-}`; `nounset_test.sh` covers every documented call form.
- `github_release` returned an empty tag on Solaris. `tr` converted `echo`'s
  trailing newline to a space, leaving `sed` an unterminated final line, which
  SVR4 sed drops. Only surfaced once there was a Solaris CI leg.
- `github_release` returned whatever its `sed` found, so a non-GitHub host or
  an error page yielded a garbage tag (`<!DOCTYPE html> <html lang=`) and a
  baffling 404 later. The result is now validated.
- The installer used `install(1)` to place binaries. It is not in POSIX and
  Solaris/illumos ship the SVR4 version with different grammar, so installs
  failed there entirely.
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
- `http_download_ftp`, for OpenBSD and NetBSD, whose only base downloader is
  `ftp(1)` — which despite the name does HTTP and HTTPS. Two different
  programs answer to that name and they differ in the one way that matters:
  NetBSD's tnftp has `-H` for arbitrary request headers, OpenBSD's ftp has no
  header support at all. The branch probes the binary's own usage line rather
  than trusting `uname -s`, and fails loudly where a header cannot be sent.
  Dispatch order is curl, wget, fetch, ftp; `ftp` is last because a Linux box
  may carry a legacy client that cannot fetch a URL at all.

  `Accept` is refused on this branch even where `-H` exists. tnftp writes its
  own `Accept: */*` ahead of any `-H` header and nothing suppresses it, so the
  caller's Accept is delivered but never wins — GitHub answered with the HTML
  release page. Refusing beats returning the wrong representation.
  `fetch(1)` is unaffected: `HTTP_ACCEPT` replaces its Accept rather than
  adding to it.

  **Net effect for OpenBSD and NetBSD users:** downloading a release artifact
  and its checksum file works, so an installer pinned to an explicit tag is
  fine. Resolving `latest` through `github_release` does not, and says so.
- **OpenBSD, NetBSD and DragonFly CI**, under QEMU via `vmactions`. Beyond the
  full suite these assert that `uname -s` maps to `openbsd` / `netbsd` /
  `dragonfly`, and that the `ftp -H` probe agrees with the real binary on each
  — in opposite directions, so either usage line changing is caught. OpenBSD
  and NetBSD also assert curl, wget and fetch really are absent, since there
  the absence is what makes the `ftp(1)` branch run. NetBSD downloads over
  `ftp -H` for real and pins the Accept refusal; DragonFly calls
  `http_download_fetch` directly, including with an Accept header, which is
  the only proof that what these downloaders send is what GitHub accepts.
- `nounset_test.sh`, which runs every documented call form under `set -u`.
- **`install_exe`** — copy a file into place and make it executable. Placing a
  binary portably is a shell primitive, so it belongs in the library rather
  than inside the installer: `install(1)` is not in POSIX and its grammar
  differs by platform. It unlinks the destination first, so replacing a binary
  that is executing cannot hit ETXTBSY.
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
