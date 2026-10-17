# Defining tools

A capsule's tools come in three tiers:

- **Developer tools** (languages, linters, IaC and cluster tools) — declared in
  the capsule's `mise.toml` and installed by mise into the home volume on first
  boot (the `mise` target). Covered here.
- **Cloud CLIs** (`aws`, `gcloud`, `az`) and **coding agents** (`claude-code`,
  `copilot`, `kiro-cli`, `gemini`) — built into the image from vendor channels,
  selected per capsule with the `CLOUD_CLIS` / `CODING_AGENTS` build args. See
  [`IMAGES.md`](IMAGES.md) for the structure and
  [`SECURITY.md`](../SECURITY.md) for anchors.

This page covers the first tier.

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

Many CLIs are available through a backend, so they belong in `[tools]`. Tools
can also be declared in table form when you need to pass extra options:

```toml
[tools]
node = { version = "22.11.0" }
```

Tools declared via a backend are resolved, verified, and lockable by mise just
like registry tools. See the [mise backends](https://mise.jdx.dev/dev-tools/backends/)
docs for the full list.

## Cloud CLIs and coding agents — image layers

Credential-bearing tools (the cloud CLIs `aws`, `gcloud`, `az` and the coding
agents `claude-code`, `copilot`, `kiro-cli`, `gemini`) are **not** declared in
`mise.toml`. They are built into the image from each vendor's channel against a
pinned trust anchor, selected per capsule with the `CLOUD_CLIS` and
`CODING_AGENTS` build args:

```yaml
build:
  context: <fenix-images checkout>
  target: mise
  args:
    CLOUD_CLIS: "aws"
    CODING_AGENTS: "claude-code"
```

See [`IMAGES.md`](IMAGES.md) for the decision guide, the per-tool table
(channel, anchor strength, update model, approximate size) and recommended
standard profiles, and [`SECURITY.md`](../SECURITY.md) for the trust model.

## IaC and cluster tools — via mise

terraform, opentofu, terragrunt, kubectl and helm go in `[tools]`, not an image
layer: they consume credentials the cloud CLIs produce, are run by a human, and
need per-project versions mise provides per directory. Prefer a backend that
verifies signatures or attestations, pin the version, and commit the locks:

```toml
[tools]
opentofu = "1.9.1"     # aqua backend verifies the cosign signature
terraform = "1.16.5"   # HashiCorp GPG-signed SHA256SUMS
kubectl = "1.37.1"
helm = "3.17.0"
```

- Commit `mise.lock` (and `.mise/locks/` for `pypi:` tools) so mise rejects a
  download whose checksum does not match.
- Commit `.terraform.lock.hcl` so provider versions and hashes are pinned — the
  providers and charts, not the CLI binary, are the real supply-chain surface.
- Confirm what a tool's backend verifies before relying on it (e.g. OpenTofu via
  `aqua:` carries a cosign signature; HashiCorp releases ship a GPG-signed
  `SHA256SUMS`). A checksum-only backend is weaker; note it.

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

## Reclaiming disk

Each distinct image selection is a separate image above the shared base, and a
base security update invalidates every layer above it, so superseded layers
accumulate. Reclaim them periodically:

```bash
docker image prune        # dangling layers
docker image prune -a     # also images no capsule references (re-pull/rebuild on next use)
```

Self-updated agent versions accumulate in the **home volume**, not the image
(each claude-code update is ~285 MB). Remove old copies under
`~/.local` in the capsule, or recreate the volume, when they pile up.
