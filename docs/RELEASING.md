# Releasing shlib

## TL;DR

```sh
# make sure actions is green

# set new VERSION, use suffix ".1", ".2" if needed
date -u +%Y.%m.%d > VERSION

# update CHANGELOG

# make release artifacts
make dist
git add VERSION dist/ CHANGELOG.md
git commit -m "release $(cat VERSION)"
git push

# wait for green

# tag and push
git tag "v$(cat VERSION)"
git push --tags
```

## Background

A release publishes the two concatenated bundles and their checksums, so that
install-script authors can pull a current copy.

Versions are **CalVer** — `2026.08.27`, the date of the release.

Tags are the version with a `v` prefix: `v2026.08.27`.

---

## Before you start

- Push access to `client9/shlib`.
- Nothing to install locally — `make tools` fetches pinned `shellcheck` and
  `shfmt` into `./bin` if you want to lint before pushing.
- `make hooks` enables a pre-commit hook that runs lint and the generated-file
  check, so a stale `dist/` or `docs/API.md` is caught before the push.
- Work on `master`. Releases are cut from `master`.

---

## Step 1 — check that `master` is green

```sh
gh run list --branch master --limit 15
```

## Step 2 — bump `VERSION`

```sh
date -u +%Y.%m.%d > VERSION
```

If you cut two releases on the same day, add a suffix: `2026.08.27.1`.

## Step 2b — move the CHANGELOG heading

Rename `## Unreleased` in [CHANGELOG.md](../CHANGELOG.md) to the version you
just put in `VERSION`, and start a fresh `## Unreleased` above it.

## Step 3 — rebuild `dist/`

```sh
make dist
```

Writes `dist/shlib.sh`, `dist/install-base.sh`, and `dist/checksums.txt`, each
stamped with the new version. These files are **committed to the repo**, so that
consumers can fetch a stable raw URL:

```
https://raw.githubusercontent.com/client9/shlib/master/dist/shlib.sh
```

## Step 4 — verify locally

```sh
make lint                        # shellcheck + shfmt, including dist/shlib.sh
make test                        # all test files under /bin/sh
make test-all                    # ... under every shell installed locally
git diff --exit-code dist/       # must be clean AFTER `make dist`
```

`dist_test.sh` sources `dist/shlib.sh` and exercises it directly, so the
artifact you are about to publish is tested, not just the sources it came from.

## Step 5 — commit

```sh
git add VERSION dist/ CHANGELOG.md
git commit -m "release $(cat VERSION)"
git push
```

Wait for Actions to return green.

## Step 6 — tag and push

```sh
git tag "v$(cat VERSION)"
git push --tags
```

Pushing the tag triggers `.github/workflows/release.yml`, which:

1. checks the tag matches `VERSION` (`v2026.08.27` vs `2026.08.27`)
2. installs the test dependencies (openssl, bzip2, xz, zstd, zip, unzip);
3. re-runs `make dist` and fails if `dist/` is not in sync;
4. runs `make test`;
5. publishes the release with `gh release create --generate-notes`, attaching
   `shlib.sh`, `install-base.sh`, and `checksums.txt`.

## Step 7 — confirm

```sh
gh release view "v$(cat VERSION)"
curl -sSfL https://github.com/client9/shlib/releases/latest/download/checksums.txt
```

Check that all three assets are attached -- `shlib.sh`,
`install-base.sh` and `checksums.txt` -- and that the version marker in the
published bundle is right:

```sh
curl -sSfL https://raw.githubusercontent.com/client9/shlib/master/dist/shlib.sh \
  | sed -n 's/^shlib \(.*\)/\1/p'
```


```sh
tmp=$(mktemp -d) && cd "$tmp"
for f in shlib.sh install-base.sh checksums.txt; do
  curl -sSfL -O "https://github.com/client9/shlib/releases/download/v$(cat VERSION)/$f"
done
sha256sum -c checksums.txt        # or: shasum -a 256 -c checksums.txt
```

---

## Dry run

The release workflow is the one piece that cannot be tested locally. To exercise
it without publishing a real version, tag a release candidate:

```sh
git tag v2026.08.27-rc1 && git push --tags
```

`v*` matches, so the workflow runs — but the tag/`VERSION` check will fail it at
step 1, which at least proves the trigger and checkout work. To test all the way
through to a published release, temporarily put `2026.08.27-rc1` in `VERSION`,
`make dist`, and commit on a branch. Delete the test release and tag afterwards:

```sh
gh release delete v2026.08.27-rc1 --yes
git push --delete origin v2026.08.27-rc1
```

---

## If something goes wrong

**Tag pushed with the wrong `VERSION`.** The workflow fails at the first step and
publishes nothing. Fix `VERSION`, `make dist`, commit, then move the tag:

```sh
git tag -d "v$(cat VERSION)"
git push --delete origin "v$(cat VERSION)"
git tag "v$(cat VERSION)" && git push --tags
```

**`dist/` out of sync.** You edited a `.sh` and forgot `make dist`. Run it,
commit the result, and retag.

**Release published with a bad artifact.** Do not rewrite a published tag —
embedded copies may already point at it. Cut a new dated version instead; that is
what CalVer is for.

**Need to re-run a failed release.** Re-run the workflow from the Actions tab, or
use `workflow_dispatch`. Deleting and re-pushing the tag also works.

---

## After the release

Consumers who fetch the raw URL at build time pick it up automatically — no
action needed. See [EMBEDDING.md](EMBEDDING.md) for the pattern shlib recommends
to install-script authors.
