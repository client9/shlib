# Example configs

Four real projects, each with a different release-naming scheme. Every one is
tested against the actual asset names from the release noted, and all four
install successfully today.

Full guide: [../../docs/INSTALLERS.md](../../docs/INSTALLERS.md).

## What each one shows

| example | what it shows |
| ------- | ------------- |
| [`gosec.sh`](gosec.sh) | the simple case — canonical GOOS/GOARCH, `tar.gz` everywhere, no hooks at all |
| [`hydra.sh`](hydra.sh) | renamed OS and arch (`darwin`→`macOS`, `amd64`→`64bit`), a hyphen instead of an underscore, and `.zip` on windows |
| [`task.sh`](task.sh) | **no version in the archive name** — which a `{name}_{version}_{os}_{arch}` template cannot express — plus folding `armv6`/`armv7` back to `arm` |
| [`golangci-lint.sh`](golangci-lint.sh) | 27 platforms, and the binary is **nested in a versioned directory** inside the archive |

## The same thing, concretely

| example | a real asset name | hooks it needs |
| ------- | ----------------- | -------------- |
| `gosec.sh` | `gosec_2.29.0_darwin_arm64.tar.gz` | none |
| `hydra.sh` | `hydra_26.2.0-macOS_arm64.tar.gz` | `adjust_os` `adjust_arch` `adjust_format` |
| `task.sh` | `task_darwin_arm64.tar.gz` | `adjust_arch` `adjust_format` |
| `golangci-lint.sh` | `golangci-lint-2.13.1-darwin-arm64.tar.gz` | `adjust_format` `binary_path` |

Verified against gosec v2.29.0, hydra v26.2.0, task v3.53.1 and
golangci-lint v2.13.1.

## Try one

```sh
cat install/examples/gosec.sh dist/install-base.sh > install.sh
sh install.sh -b ./bin           # -> installed ./bin/gosec
sh install.sh -b ./bin v2.22.0   # or pin a tag
```

## Which to copy

Start from `gosec.sh`. If your archive names use different spellings than
`uname_os`/`uname_arch` produce, look at `hydra.sh`. If the binary is not at the
root of the archive, look at `golangci-lint.sh`.

`task.sh` is the one worth reading if you are coming from godownloader: its
archives carry no version at all, so there is no template string that produces
the right name. As a shell function it is a one-liner.

## These are tests, not just documentation

[`install_test.sh`](../../install_test.sh) asserts that each config produces the
exact filenames listed above, and that each assembles into a script that parses.
If a config drifts, the suite fails.

That is deliberate: three of the four bugs found while building this — a
multi-line `PLATFORMS` list that never matched, the nested-archive case, and a
ksh93 quirk that swallowed an error message — were caught by running these
against real releases rather than by unit tests.

The flip side is that these assertions are pinned to projects nobody here
controls. If one of them renames its artifacts, the failure is upstream drift
rather than a bug in shlib.
