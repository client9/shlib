# Embedding shlib in an install script

shlib is meant to be copied into other people's scripts. That is the whole
point — a `curl ... | sh` installer cannot have dependencies, so the functions
have to travel with it.

The catch is that a copy is a snapshot. Bugs get fixed here and the copies never
hear about it. Copies that were made in 2018 are still in circulation, still
failing on Windows in a way that was fixed years ago.

**So: do not vendor by hand. Fetch the bundle as part of your build.**

## Get the bundle

Every change to the library regenerates two files, both committed to this repo:

| file | what it is |
| ---- | ---------- |
| [`dist/shlib.min.sh`](../dist/shlib.min.sh) | comments stripped — embed this |
| [`dist/shlib.sh`](../dist/shlib.sh) | full, with comments — easier to read when debugging |

Three ways to get them, in order of preference:

**1. Fetch the latest at build time** (recommended). The URL is stable and always
points at the newest bundle:

```sh
curl -sSfL -o vendor/shlib.min.sh \
  https://raw.githubusercontent.com/client9/shlib/master/dist/shlib.min.sh
```

**2. Pin to a release** if you need reproducible builds. Releases are dated
(`v2026.08.28`) and carry `checksums.txt`:

```sh
tag=v2026.08.28
base=https://github.com/client9/shlib/releases/download/$tag
curl -sSfL -o vendor/shlib.min.sh   "$base/shlib.min.sh"
curl -sSfL -o vendor/checksums.txt  "$base/checksums.txt"
grep 'shlib\.min\.sh$' vendor/checksums.txt | (cd vendor && sha256sum -c -)
```

**3. Clone and build** if you want to pick your own subset of functions:

```sh
git clone https://github.com/client9/shlib.git
cd shlib && make dist        # writes dist/
```

## Wire it into your build

The goal is that nobody has to remember to update anything. Put the fetch in
whatever step regenerates your install script, so a current copy lands on every
release:

```make
vendor/shlib.min.sh:
	mkdir -p vendor
	curl -sSfL -o $@ https://raw.githubusercontent.com/client9/shlib/master/dist/shlib.min.sh

install.sh: vendor/shlib.min.sh install.sh.in
	cat vendor/shlib.min.sh install.sh.in > $@
```

If you would rather pin, do it — just make sure *something* prompts you to move
the pin. A dated tag makes that visible; Dependabot and friends will not do it
for you, because a vendored shell file is not a dependency they can see.

## Keep the version marker

Each bundle starts with a marker that survives comment-stripping:

```sh
cat /dev/null <<EOF
shlib 2026.08.28
https://github.com/client9/shlib
EOF
```

Two lines, no runtime cost. Leave them in. When someone reports an odd failure
in your installer, this is what tells you at a glance whether they are running a
current copy:

```sh
sed -n 's/^shlib \([0-9.]*\)$/\1/p' install.sh
```

## Do not hand-edit the embedded block

If a function needs changing, change it upstream and re-fetch. Local edits are
invisible to everyone, get silently reverted the next time someone regenerates,
and make the version marker a lie.

Bug reports and pull requests are welcome:
<https://github.com/client9/shlib/issues>

## Point your users at *your* issue tracker

shlib's own error messages are deliberately generic:

```
uname_os_check 'Haiku' got converted to 'haiku' which is not a recognized OS name
```

They used to end with "Please file bug at https://github.com/client9/shlib",
which meant every stale copy in the world sent its bug reports upstream — usually
for bugs that had already been fixed. They no longer do.

That means your installer should say where *you* want problems reported. A wrapper
around `log_crit`, or a trap that prints your support URL on failure, is enough.

Two things worth handling yourself, because shlib cannot know them:

- **Platforms you do not publish binaries for.** `uname_os` mapping to `windows`
  only means the detection worked. If you ship no Windows build, say so plainly
  rather than letting the download 404.
- **Which architectures your release actually has.** `uname_arch_check` validates
  against shlib's list of recognized names, not against your release assets.

---

## Maintainer note

Cutting a release is documented separately in [RELEASING.md](RELEASING.md).
