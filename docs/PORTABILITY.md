# Portability notes

Shell- and platform-specific behaviour that has actually broken this library,
with the evidence and the resulting rule. Every entry here cost a red CI leg or
a bug report to find; none of it is speculative.

This is a **lookup table for when something is red on one platform and green
everywhere else**, so it is grouped by the shell or system that surprises you
rather than by the shlib function involved. The project's own conventions,
architecture and open work live in [CONTRIBUTING.md](../CONTRIBUTING.md).

Two habits that make this file shorter over time:

- When a leg goes red for a reason that is not shlib's bug, add the entry here
  rather than working around it silently.
- Prove the surprise before recording it. Several entries below were first
  diagnosed wrongly, and the wrong diagnosis suggested a fix that would not
  have worked.

## Shells

### bash 3.2 — macOS `/bin/sh`

- **bash 3.2 (macOS `/bin/sh`) mis-parses `case` inside `$( )`** — it reads the
  pattern's closing `)` as the end of the command substitution. The balanced
  form `(pattern)` fixes it, but shfmt normalises that straight back out, so
  the practical rule is: no `case` inside a command substitution.

### ksh93

- ksh93 on Linux implements pipelines with **socketpairs**, so `/dev/stdin` is a
  socket and cannot be opened by path. Never pass `/dev/stdin` as a filename;
  invoke the tool with no file operand so it reads fd 0.

- **ksh93 does not honour a function redefined inside a subshell** — the caller
  still resolves the outer definition, where sh/dash/bash/zsh all pick up the
  stub. So test stubs cannot be scoped with `( … )`. Stub at the top level and
  drive behaviour with variables; see the `execute` tests in `install_test.sh`.
  Repeatedly redefining and `unset -f`-ing functions also made ksh93 crash.

- **ksh93 loses a function's stderr** when the function contains a nested
  command substitution and the caller captures it with `$(f 2>&1)`. This
  silently swallowed an error message; the fix was to move the command
  substitution out of the function — see `normalize_platforms` in
  `install/runner.sh`.

### zsh

- **zsh sets `$0` to the function name inside a function** (`FUNCTION_ARGZERO`);
  POSIX shells report the script name in every scope. So `log_prefix` prints
  "log_prefix" under zsh. Not portably fixable — capturing at file scope gives
  zsh the sourced library's own path — and it only affects a log-line prefix,
  which `log_prefix` exists to let callers override. `log_test.sh` skips that
  one assertion on zsh rather than asserting something false.

- **zsh treats an unmatched glob as an error** (`NOMATCH`), where POSIX shells
  pass the pattern through. So `for f in "$d"/*` is not a portable way to walk
  a possibly-empty directory.

- **zsh does not word-split unquoted parameters.** `for p in $LIST` iterates
  once over the whole string. Use `case " $LIST " in *" $item "*)` instead —
  see `check_platform` in `install/runner.sh`. The same applies to iterating a
  list: `execute` peels `BINARIES` with parameter expansion rather than `for`.

- **`zsh` DOES word-split command substitution**, even though it does not
  word-split parameter expansions. So `for x in $(printf '%s' "$LIST")` works
  on all of sh/dash/bash/ksh/zsh, and default IFS folds tabs and newlines for
  free. It is still **not** used for `BINARIES`, because the results are then
  pathname-expanded and that behaviour inverts: a `*` in the list globs against
  the cwd on the POSIX shells and passes through literally on zsh. `set -f`
  would cost back the lines saved. The peel loop in `execute` carries this
  reasoning so it does not get "simplified" into the unguarded form.

### posh

- **posh's `getopts` is unreliable in a `-c`/eval context** with no positional
  parameters: it walks garbage, reports `invalid option -- ''`, and drives
  `parse_args` into its `\?` branch and `usage`'s `exit 2`. It is a harness
  artifact, not a shlib bug -- a real assembled installer run as a *script*
  under posh parses `-b DIR` and an explicit tag correctly. `nounset_test.sh`
  skips that one assertion when `POSH_VERSION` is set.

### Any shell

- **`while read` from a pipe runs in a subshell**; from a redirect it does not.
  Accumulating into a variable needs the redirect form.

- **`eval` confines a nounset abort in ksh93 and zsh.** sh, dash and bash tear
  the whole subshell down when `set -u` hits an unset parameter; ksh93 and zsh
  stop only the `eval` and carry on. So `( set -u; eval "$code"; echo OK )`
  reaches the sentinel unconditionally on exactly those two shells, and every
  assertion built on it passes vacuously. `nounset_test.sh` appends the
  sentinel INSIDE the eval string instead. Its `test_detects_a_violation` --
  a self-check that the harness can still fail -- is what caught this; a probe
  that cannot be shown to fail is not a test.

## Platforms

### Solaris and illumos

- **Solaris ships pre-POSIX tools.** `/usr/bin/grep` is the SVR4 one: none of
  `-o`, `-E`, `-F`, `-x`, `-f`. `find` has no `-mindepth`/`-maxdepth`. Use
  `sed -n 's/…/\1/p'`, `ls -A | wc -l`, and `sort | uniq -u` for a set
  difference. Note the linter pushes the other way -- SC2012 objects to `ls`,
  and taking its advice is what broke Solaris.

- **`head -c` does not exist.** POSIX `head` specifies only `-n`, and Solaris
  ships exactly that; `-c` is a GNU/BSD extension. Instead of failing, SVR4
  head prints `usage: head [-n #] [-#] [filename...]` on stderr and exits 2,
  so a pipeline using it silently yields the usage line or nothing at all.
  `http_last_modified` shipped with `tail -c 31 | head -c 29` for years and
  returned nothing on Solaris the whole time. Use `dd if=f bs=N count=1` for
  bytes, or match the text with `sed`.

  Cheap to rehearse without a VM: put a wrapper named `head` early on `PATH`
  that rejects `-c` the way SVR4 head does, and run the suite under it.

- **SVR4 sed drops a final line with no terminator.** `echo x | tr -s '\n' ' '`
  turns the trailing newline into a space, so sed sees an unterminated line and
  Solaris yields nothing where BSD and GNU yield the answer. This silently
  broke `github_release`. Feed sed with `printf '%s\n'`, never `printf '%s'`.

- **`command -v NAME`'s exit status does not mean "the config defined a
  function".** It means a command of that name exists anywhere -- and Solaris
  and illumos ship `/usr/bin/unpack`, so the `unpack` hook guard found it,
  skipped its default, and every install there ran the SVR4 `unpack(1)`.
  Compare the *output* instead: `command -v` prints the bare name for a
  function or builtin, an absolute path for an external program. Any hook name
  can collide; the guard, not the name, is what has to be right. Rehearse this
  leg without a VM by putting a fake executable of that name on PATH.

### NetBSD

- **`[ -w ]` is not a capability check, and on NetBSD it is not even an
  approximation.** NetBSD's `test(1)` deliberately does not call `access(2)`:
  it stats the file and reads `st_mode` directly, and for root treats "any of
  the three write bits set" as writable (`bin/test/test.c`, `test_access`).
  A mode `0500` directory has no write bit anywhere, so `[ -w ]` says no while
  root writes to it happily. Linux, macOS and FreeBSD use `access()`/
  `eaccess()`, where root simply gets yes -- so a root-guard written as
  `[ -w "$dir" ]` skipped correctly everywhere else and went red only on
  NetBSD. Guard by **probing the capability** (`touch "$dir/probe"`), which is
  what the assertion actually depends on. See `install_exe_test.sh`.

### FreeBSD

- FreeBSD needs `gmake`: the Makefile uses `.DEFAULT_GOAL`, `MAKEFILE_LIST` and
  `--no-print-directory`, all GNU-only. It deliberately does **not** install
  curl or wget — base has neither, only `fetch(1)` — so it is the only leg that
  exercises `http_download`'s fetch branch. The workflow asserts curl/wget are
  absent, so a transitive dependency pulling curl in cannot silently stop that
  coverage.

### Linux

- **Inode numbers are not a proxy for "was unlinked".** Linux reuses a
  just-freed inode, so an inode-identity check reported "not unlinked" on ext4
  while passing on APFS. `install_exe_test.sh` asserts via a hard link
  instead: after an unlink-then-copy the link keeps the old contents.

### Windows — git bash and msys2

- **On Windows, `[ -x FILE ]` is not a mode-bit test.** msys2 infers
  executability from content (a `#!` line, a PE header) or a `.exe` suffix, so
  `chmod 0755` on a file of arbitrary text still reports non-executable. A
  stub standing in for a downloaded binary must therefore *look* like one --
  writing `#!/bin/sh` is enough. This is why `install_exe`'s own tests pass on
  Windows while a bare-binary fixture did not.

- `.gitattributes` pins the whole tree to `eol=lf`, and marks `fixtures/**` as
  `-text` so it is never converted. Git on Windows defaults to
  `core.autocrlf=true`; a shell script with CRLF fails in ways that look like
  anything but line endings, and a CRLF *fixture* fails worse — the hash tests
  report a digest that looks arbitrary (md5 of `foobar\r\n`, not `foobar\n`).
  An extension-by-extension attributes file missed the fixtures and produced
  exactly that. The windows workflow asserts LF rather than trusting it.

### Container images

- **A container image is not a platform, and routinely has no downloader at
  all.** Measured: `debian:stable-slim`, `ubuntu:24.04`, `node:22-slim` and
  `python:3.12-slim` all ship neither curl nor wget.

  | image | curl/wget | usable interpreter |
  | ----- | --------- | ------------------ |
  | `python:3.12-slim` | none | `python3` |
  | `node:22-slim` | none | `node` |
  | `debian:stable-slim` | none | none |
  | `ubuntu:24.04` | none | none |

- **Perl is present on all four and useless on all four.** Debian's
  `perl-base` carries neither `IO::Socket::SSL` nor `LWP`, and the images ship
  no `openssl` binary to shell out to, so there is no path to an HTTPS URL.
  That is why `http_download_python` and `http_download_node` exist and no
  perl branch does -- perl is available exactly where it cannot help.

- **`node`'s https module does not follow redirects; `fetch()` does.** Every
  GitHub release download redirects to `objects.githubusercontent.com`, so an
  https-based branch would need its own redirect loop. `http_download_node`
  uses the global `fetch()` (node 18+) and streams the body to disk rather
  than buffering it -- release artifacts run to hundreds of megabytes.

- **Debian and Ubuntu called the interpreter `nodejs` for years**, because
  `node` belonged to the ax25 package. `http_download_node` accepts either
  name.

- **`debian:stable-slim` and `ubuntu:24.04` are not short of networking --
  they are short of TRUST.** They ship `apt`, and `/usr/lib/apt/apt-helper
  download-file <url> <dest>` is a perfectly good general-purpose HTTPS client
  with a full set of transport methods in `/usr/lib/apt/methods/` (including
  `https`). What they do not ship is a CA store:

  | image | system CA roots | why it still installs packages |
  | ----- | --------------- | ------------------------------ |
  | `debian:stable-slim` | **0** | `apt` points at `http://deb.debian.org` and verifies by GPG signature, not TLS |
  | `ubuntu:24.04` | **0** | same, `http://ports.ubuntu.com` |
  | `node:22-slim` | **0** | node does not use the system store -- it bundles 145 roots of its own (`tls.rootCertificates`) |
  | `python:3.12-slim` | 150 | that image installs `ca-certificates` |

  So on the two bare distro images, *nothing* can verify a TLS peer --
  apt-helper included:

  ```
  SSL connection failed: error:0A000086:SSL routines::certificate verify failed
  ```

  Install `ca-certificates` and apt-helper downloads GitHub release assets
  fine, cross-host redirects and all. The gap is the trust store, not the
  transport.

- **An `apt-helper` branch was considered and rejected.** It is a real base
  tool on the one family that has it, which is more than can be said for the
  runtimes -- but:
  - On the images where it would be the *only* option it cannot verify
    certificates, so adding it would turn a clear "no downloader found" into a
    confusing TLS error that reads like an shlib bug.
  - Where `ca-certificates` is installed, curl or wget almost always is too.
  - It cannot send arbitrary request headers -- there is no `Acquire::` config
    key for them -- so `github_release` could not resolve `latest` through it,
    the same limitation as `fetch(1)` and `ftp(1)`.
  - It lives at `/usr/lib/apt/apt-helper`, off `PATH`, and is an apt internal
    with no stability promise.

  The honest outcome on a bare `debian:stable-slim` is the error
  `http_download` already prints. The fix is an `apt-get install`, and it is
  the user's to make.

- **Installing curl on those images is not always enough.** `ca-certificates`
  is a *Recommends* of curl, not a *Depends*, so the very common Dockerfile
  idiom leaves you with a downloader and still no trust store:

  ```
  apt-get install -y --no-install-recommends curl
  curl: (77) error setting certificate file: /etc/ssl/certs/ca-certificates.crt
  ```

  Anyone reporting that an installer "fails on Debian" is likely to have hit
  this rather than anything in shlib. The fix is
  `apt-get install -y --no-install-recommends ca-certificates curl`.

## Tools that are not POSIX

### `install(1)`

- **`install(1)` is not POSIX either, and its grammar differs by platform.**
  GNU and BSD take `install SRC DST`; Solaris and illumos ship the SVR4
  version, which does not, so every install failed there. That is what
  `install_exe` exists for -- it is a library function, not installer-local,
  because placing a file portably is a shell primitive.

### `mktemp(1)`

- **`mktemp` is not POSIX and its mode is not guaranteed.** git-bash creates
  `0755`, not `0700`, so `mktmpdir` sets the mode explicitly instead of
  inheriting it. On Windows the bits are an emulation over NTFS ACLs, so
  `mktmpdir_test.sh` asserts owner-usability there rather than a mode string.

### Downloaders: `fetch(1)` and the two `ftp(1)`s

- **`fetch(1)` cannot send arbitrary headers** — there is no `-H`. It honours
  `HTTP_ACCEPT`, which covers `github_release`'s `Accept: application/json`.
  `Authorization` (github_api with `GITHUB_TOKEN`) has no equivalent and fails
  with a clear message rather than silently sending an unauthenticated
  request.

- **Two different programs answer to `ftp`, and only one can send headers.**
  OpenBSD's ftp (getopt `46AaCc:dD:EeN:gik:Mmno:pP:r:S:s:TtU:uvVw:`) has no
  `-H` at all; NetBSD's tnftp (`:46Aab:defgH:iN:no:P:pq:Rr:s:T:tu:Vvx:`) does.
  `-o` and `-V` are the only flags common to both — OpenBSD's `-M` does not
  exist in tnftp. So `http_download_ftp` **probes the binary**, not `uname -s`:
  `ftp -Z </dev/null 2>&1 | grep '\[-H '`. `-Z` is invalid in both, so each
  prints its usage line and exits without touching the network; `</dev/null`
  stops a legacy client dropping into its interactive loop. The openbsd and
  netbsd legs assert the probe's answer against the real binary, in opposite
  directions, so the day either usage line changes CI says so.

- **A header that is delivered is not necessarily a header that works.**
  tnftp's `-H` really does put the header on the wire — and it is still
  useless for `Accept`, because `print_get` in `usr.bin/ftp/fetch.c` writes
  its own `Accept: */*` first and nothing suppresses it. GitHub honours the
  first `Accept` it sees, so `github_release` over tnftp got the HTML release
  page and parsed `<!DOCTYPE html> <html lang=` as the tag. Verified against
  the live endpoint: `application/json` alone returns JSON; `*/*` ahead of it
  returns HTML, as does every q-value arrangement, including a single
  `Accept: application/json, */*;q=0` — GitHub is not doing real q
  negotiation. So `http_download_ftp` **refuses `Accept:` outright**, on both
  flavours, while still passing other headers through `-H`. A silently wrong
  body is worse than a clear failure.

  `fetch(1)` does not have this problem: `HTTP_ACCEPT` replaces its `Accept`
  rather than adding to it. The dragonflybsd leg proves that end to end, and
  it is the reason the fetch branch supports the header and the ftp branch
  does not.

  Consequence worth knowing: on **both** OpenBSD and NetBSD, `github_release`'s
  `latest` lookup cannot work and says so. Plain release downloads — the
  artifact and its checksum file — are unaffected, so an installer pinned to
  an explicit tag works fine. Closing the gap is open work; see
  [Resolving `latest` without content negotiation](../CONTRIBUTING.md#1-resolving-latest-without-content-negotiation).

## Rehearsing a platform without the platform

- Reproduce any leg locally with docker; that is how every change here was
  verified before pushing. The BSD/SunOS legs cannot boot locally, but the
  part that usually breaks -- *which downloader is present* -- can be
  rehearsed without a VM: build a directory of symlinks to every base tool
  except curl/wget/fetch, drop in a shell script named `ftp` (or `fetch`) that
  emulates the real one's flag parsing and shells out to curl by absolute
  path, then run the workflow's `run:` block under `env -i PATH=thatdir sh -u`
  (`-u` because the vmactions runner uses it). That ran the whole suite
  through `http_download_ftp` for real before any BSD leg had booted.

  **The fake must reproduce what the real tool sends, not just the flags it
  accepts.** The first fake `ftp` parsed `-H` and passed it to curl, so the
  Accept test passed locally and failed on NetBSD — the real tnftp adds its
  own `Accept: */*` first. Once the fake did that too, it reproduced the CI
  failure exactly. A fake that only models the interface validates the
  interface, not the behaviour. What no fake can check is the base system's
  own tools, which is why each leg prints an inventory first.
