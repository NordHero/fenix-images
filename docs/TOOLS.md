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
"pypi:azure-cli" = "2.67.0"                    # PyPI package (az)
"aqua:github/copilot-cli" = "1.0.95"           # aqua registry
```

- `go:` installs `go install`-style tools.
- `ubi:` installs binaries from GitHub releases.
- `pypi:` installs Python packages (e.g. `azure-cli` -> `az`).
- `aqua:` installs from the aqua registry (e.g. GitHub Copilot CLI).

Most cloud CLIs are available through a backend, so they belong in `[tools]`,
not in `EXTRA_TOOLS`. For example gcloud, including the GKE auth plugin:

```toml
[tools]
gcloud = { version = "497.0.0", components = ["gke-gcloud-auth-plugin"] }
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
  and `.mise/locks/`. The example locks `linux-x64` and `linux-arm64`; mise
  keeps those platforms on re-runs. A `pypi:` entry needs a Python interpreter
  on `PATH` while locking.
- Mount `mise.lock` and `.mise/locks/` beside `mise.toml` (see
  [`example/compose.yaml`](../example/compose.yaml)). mise then installs the
  locked versions and rejects a download whose checksum differs from the lock;
  a `pypi:` tool fails to install without its `.mise/locks/` entry.
- The lock records checksums for registry and `aqua:` tools. Each `pypi:` tool
  gets a hash-locked uv lockfile covering all its dependencies in
  `.mise/locks/`. `go:` modules are verified by the Go checksum database at
  install. `awscli`, `gcloud` and `ubi:` entries are pinned by version only.
- CI fails when `example/mise.lock` or `example/.mise/locks/` is out of date.
- Changing a version re-provisions that tool on the next container start.
