# Building an install script

This is the replacement for [godownloader][gd], which is archived. It generated
`curl … | sh` installers by rendering a Go template against a `.goreleaser.yml`
— and it baked a 2019 snapshot of shlib into every script it produced.

[gd]: https://github.com/goreleaser/godownloader

There is no Go program here, and no template language. There does not need to
be: godownloader's entire parameterisation was four substitutions, and a shell
function is already a lazily-evaluated template.

## The shape of it

An install script is three parts concatenated:

```
config.sh            yours, ~12 lines
dist/install-base.sh ours: the shlib functions + the fixed installer logic
```

```sh
curl -sSfL -o /tmp/base.sh \
  https://raw.githubusercontent.com/client9/shlib/master/dist/install-base.sh
cat config.sh /tmp/base.sh > install.sh
```

That is the whole build step. Your config comes first because it only *defines*
things; the flow runs at the very end of `install-base.sh`, so a `curl | sh`
that gets truncated mid-transfer either does nothing or fails to parse — it
cannot run a partial install.

## Your config

```sh
OWNER=securego
REPO=gosec
BINARY=gosec
FORMAT=tar.gz
BINDIR=${BINDIR:-./bin}

# Platforms you actually publish.  This is your build matrix -- you already
# know it.  Declaring it lets the installer say "no binary for windows/arm64,
# available: ..." instead of failing with a bare 404 from the download.
PLATFORMS="darwin/amd64 darwin/arm64 linux/amd64 linux/arm64"

# How your release archive is named.
#
# A function, not a template string: it runs after VERSION, OS and ARCH are
# known, so ordinary shell expansion does the whole job.  This is the piece
# godownloader needed text/template for.
archive_name() {
  echo "${BINARY}_${VERSION}_${OS}_${ARCH}"
}

# Optional: verify the download against a checksum file.  Delete to skip
# (not recommended).
checksum_name() {
  echo "${BINARY}_${VERSION}_checksums.txt"
}
```

See [`install/config.sh.example`](../install/config.sh.example) for the
complete set, including `BINARIES` for multi-binary archives.

## Worked examples

Four real projects, each with a different naming scheme — from "no hooks at
all" through renamed arch spellings, archives with no version in the name, and
a binary nested inside a versioned directory.

**[install/examples/](../install/examples/)** — the table of what each one
shows, and which to copy.

```sh
cat install/examples/gosec.sh dist/install-base.sh > install.sh
sh install.sh -b ./bin
```

### If your filenames are unusual

Three optional hooks, run after `OS`/`ARCH`/`VERSION` are set and before the
name is built. Define only what you need:

```sh
adjust_format() { case ${OS} in windows) FORMAT=zip ;; esac; }
adjust_os()     { case ${OS} in darwin) OS=macos ;; esac; }
adjust_arch()   { case ${ARCH} in amd64) ARCH=64bit ;; esac; }
```

These replace goreleaser's old `replacements:` config. If a hook is absent, a
no-op default is used — your definition always wins.

Anything these cannot express, write directly in `archive_name`. It is a shell
function; there is no template language to fight.

### If the binary is inside a directory

Many archives put the binary at the root. Some wrap everything in a versioned
directory:

```
golangci-lint-2.13.1-darwin-arm64/golangci-lint
```

Point `binary_path` at it. `NAME` is whatever `archive_name` returned:

```sh
binary_path() { echo "${NAME}/$1"; }
```

It receives the binary name (with `.exe` already appended on windows) and
returns the path within the unpacked archive. The default is `echo "$1"`.

### Several binaries in one archive

```sh
BINARIES="task taskfile"
```

Each is installed into `BINDIR` under its own name.

## Installing from somewhere other than GitHub

Only two seams know about GitHub, out of 37 functions:

| seam | what it is | generalises? |
| ---- | ---------- | ------------ |
| `DOWNLOAD_BASE` | where artifacts live | **yes** — pure string construction, point it anywhere |
| `latest_version()` | how "latest" becomes a tag | **no** — every forge differs |

```sh
DOWNLOAD_BASE="https://downloads.example.com/widget"
RELEASES_URL="https://git.example.com/example/widget/releases"
latest_version() {
  test -n "$1" && { echo "$1"; return 0; }
  http_copy "https://git.example.com/api/v1/repos/example/widget/releases/latest" |
    sed 's/.*"tag_name":"//; s/".*//'
}
```

Resolving "latest" is the part shlib cannot do for you. Its GitHub default
works because `github.com/O/R/releases/latest` answers with JSON when sent
`Accept: application/json`. Nothing else does — GitLab returns no JSON body,
Forgejo returns an HTML page. Rather than guess at each forge's API, shlib
hands you the hook: you know your host, and a wrong guess here would surface
as a bug report against shlib rather than against the thing that changed.

Projects that always install a pinned tag need neither override.

## Regenerate on every release

**This is the part that matters.** godownloader's output was committed once and
never regenerated, which is why scripts from 2019 are still shipping a shlib
from 2019 and reporting bugs that were fixed in 2018.

Put the build in whatever step cuts your release:

```yaml
- name: build install.sh
  run: |
    curl -sSfL -o /tmp/base.sh \
      https://raw.githubusercontent.com/client9/shlib/master/dist/install-base.sh
    cat contrib/config.sh /tmp/base.sh > install.sh
- name: attach it
  run: gh release upload "$TAG" install.sh
```

Now your installer carries a current shlib on every release and nobody has to
remember anything. If you would rather pin, use a
[release asset](https://github.com/client9/shlib/releases) instead of the raw
URL — but then something has to move the pin.

## What the user sees

```
$ sh install.sh -b ./bin
securego/gosec info checking GitHub for latest tag
securego/gosec info found version 2.29.0 for darwin/arm64
securego/gosec info installed ./bin/gosec
```

And on a platform you do not build for:

```
bearer/bearer crit no binary published for windows/amd64
bearer/bearer crit available platforms: darwin/amd64 darwin/arm64 linux/amd64 linux/arm64
```

Flags: `-b <dir>` install directory, `-d` debug logging, and an optional
trailing tag (`sh install.sh v1.2.3`) to pin a version instead of taking the
latest.

## Point users at your issue tracker

shlib's error messages are deliberately generic and name no upstream project.
Earlier versions ended with "please file bug at github.com/client9/shlib",
which sent every stale copy's bugs to the wrong repo.

So your installer should say where *you* want problems reported — redefine
`log_prefix` or trap failures and print your support URL.

## Differences from godownloader

- No Go, no YAML, no template language. `cat` is the generator.
- The installer logic is a real shell file that is linted in four dialects and
  tested on 13 shells, including the assembled output. godownloader's shell
  lived inside a Go string literal and was never linted or tested.
- `PLATFORMS` is declared rather than derived from a build config, so an
  unsupported platform produces a real message instead of a 404.
- No `.goreleaser.yml` parsing, so nothing breaks when goreleaser changes its
  config schema.
