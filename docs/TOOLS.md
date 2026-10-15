# Defining tools

A capsule's tools are declared in its `mise.toml`. Nothing is baked per image;
mise installs what you declare into the home volume on first boot.

## `[tools]` — mise-managed

Declare tools with pinned versions:

```toml
[tools]
go = "1.25.13"
python = "3.12"
terraform = "1.16.5"
kubectl = "1.37.1"
```

mise covers go, python, gopls/goimports/staticcheck, golangci-lint, goreleaser,
terraform, opentofu, terragrunt, kubectl, argocd, awscli, uv, prek, pre-commit,
and more — see the [mise registry](https://mise.jdx.dev/registry.html).

### Backends

For tools not in the registry, name the backend explicitly:

```toml
[tools]
"go:golang.org/x/tools/gopls" = "0.23.0"      # go install
"ubi:j178/prek" = "0.5.5"                      # GitHub-release binary
"pypi:ansible" = "11.1.0"                      # PyPI package
"aqua:cli/cli" = "2.63.0"                      # aqua registry
```

- `go:` installs `go install`-style tools.
- `ubi:` installs binaries from GitHub releases.
- `pypi:` installs Python packages.
- `aqua:` installs from the aqua registry.

Many CLIs are available through a backend, so they belong in `[tools]`, not in
`EXTRA_TOOLS`. Tools can also be declared in table form when you need to pass
extra options:

```toml
[tools]
node = { version = "22.11.0" }
```

Tools declared via a backend are resolved, verified, and lockable by mise just
like registry tools. See the [mise backends](https://mise.jdx.dev/dev-tools/backends/)
docs for the full list.

## `[env]` and `EXTRA_TOOLS` — vendor installers

A few tools have no mise backend and must be installed by the vendor's own
script. These go in `EXTRA_TOOLS`:

```toml
[env]
EXTRA_TOOLS = "kiro-cli"
```

`extra-tools.sh` installs these. `kiro-cli` installs the vendor's latest (its
installer handles platform/glibc detection and checksum verification itself).

`EXTRA_TOOLS` are a lower trust tier than `[tools]` — they are vendor scripts,
not verified by mise or this repo. Prefer a `[tools]` backend whenever one
exists. See [`SECURITY.md`](../SECURITY.md).

## Reproducibility

- Pin every version in `[tools]`; avoid `"latest"`.
- Run `mise lock` next to `mise.toml` after any change and commit `mise.lock`
  (and `.mise/locks/` if you use `pypi:` tools). mise keeps the locked
  platforms (e.g. `linux-x64`, `linux-arm64`) on re-runs. A `pypi:` entry needs
  a Python interpreter on `PATH` while locking; the base image bakes one
  (`python3` + `python`), so this is satisfied out of the box.
- Mount `mise.lock` beside `mise.toml` (and `.mise/locks/` when present). mise
  then installs the locked versions and rejects a download whose checksum
  differs from the lock; a `pypi:` tool fails to install without its
  `.mise/locks/` entry. Locked `pypi:` installs never build from source, so
  every dependency needs a wheel for the configured `python`.
- The lock records checksums for registry and `aqua:` tools. Each `pypi:` tool
  gets a hash-locked uv lockfile covering all its dependencies in
  `.mise/locks/`. `go:` modules are verified by the Go checksum database at
  install. Version-only backends such as `ubi:` are pinned by version only.
- Changing a version re-provisions that tool on the next container start.

> The shipped `example/` is a clean template — `mise.toml` only, no committed
> lock. Run `mise lock` in your own copy to pin and verify.
