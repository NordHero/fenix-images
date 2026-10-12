# AGENTS.md

Guidance for AI agents working in this repo. This is the single agent-facing
doc; everything else is written for humans.

## Hard rules

1. **No comments in code files.** Dockerfiles and shell scripts contain plain
   code only (shebang allowed). Put explanations in docs, not inline.
2. **Docs are compact and factual.** State what is. Omit history, decision
   narration, and verbose justification.
3. **No secrets.** Credentials never live in the image or the repo; they stay in
   the home volume (`/home/dev`) at runtime, authenticated by the user.

## Project

**fenix-images** builds a single, minimal non-root development base image with
[mise](https://mise.jdx.dev) baked in, and ships a sample capsule. It is
**Layer 3** of [fenix](https://github.com/NordHero/fenix) — the development
model fenix (host Layers 0–2) leaves out of scope. It is self-contained: usable
with nothing but `docker compose`.

Tools are **not** baked per image; they are declared in a `mise.toml` and
installed into the home volume on first boot. A **capsule** is a folder with
`compose.yaml` + `mise.toml` defining one encapsulated runtime; **capsules** is
the plural.

The documented flow is self-contained and build-it-yourself: users clone this
repo, build the base image locally (`./build-images.sh` -> `fenix-base:local`),
and reference that local image from their capsules. The repo is private and
publishes no image; the documented flow is build-it-yourself.

## Where things live

- `Dockerfile` — the base image (OS + eye-candy + mise). Root context.
- `base/` — files copied into the image (entrypoint, provision, zshrc, p10k,
  xclip shim, `capsule-info`, `capsule-sync`). Provenance (`IMAGE_VERSION`/`SOURCE_COMMIT`/
  `BUILD_DATE` build-args) is written to `/etc/capsule/info.json`, the
  `CAPSULE_INFO` env, and OCI image labels. `capsule-sync` clones repos declared
  in `CAPSULE_REPOS` / `~/.capsule-repos` idempotently via the gh credential helper.
- `extra-tools.sh` — installs tools with no mise backend (currently only
  `kiro-cli`); reads `EXTRA_TOOLS` from the mounted `mise.toml`. Cloud CLIs
  (azure-cli, copilot, gcloud) are declared in `[tools]` via mise backends.
- `build-images.sh` — builds the Dockerfile and tags it `fenix-base:local`
  (`REGISTRY=fenix`, `TAG=local` by default).
- `example/` — the shipped example capsule (`compose.yaml` + `mise.toml`). It
  is the canonical default: the reference used while developing the image and
  the target of CI's config validation. `example/mise.toml` is the extensive
  default tool list; keep it authoritative. The kapsuli CLI does not couple to
  it — users opt in by copying it into their own
  `~/.kapsuli/archetype/mise.toml` (what `kapsuli new` scaffolds from).
- `docs/` — human depth: `DESIGN.md` (runtime behavior), `TOOLS.md` (declaring
  tools in `mise.toml`).
- `.github/workflows/` — `build-images.yml` (PR/main: build + verify + scan),
  `release-please.yml` (version PRs + tags/CHANGELOG),
  `scheduled-rebuild.yml` (weekly no-cache rebuild + Trivy scan; no publish).

There is no root `compose.yaml` or root `mise.toml`; the example capsule is the
single reference.

## Trust

mise and its tool backends are the trust point for `[tools]`: declared tools are
resolved and verified by mise (pinned + checksum-verified mise, Sigstore/SLSA
provenance, `mise lock` digests). A `mise.toml` with `[env]` is untrusted until
trusted; the entrypoint trusts the mounted `mise.toml` on start.

`EXTRA_TOOLS` are a **separate, lower trust tier**: vendor installers run over
TLS but are not checksum- or signature-verified by this repo. Do not claim
otherwise in docs. See `SECURITY.md` and issue #51.

## Conventions

- Non-root `dev` user (UID/GID 1000); home at `/home/dev`.
- Tool versions are pinned in `mise.toml`; `extra-tools.sh` supports
  `tool@version` where the installer allows it.
- Prefer a `[tools]` backend (`pypi:`, `aqua:`, `go:`, `ubi:`, `vfox:`, ...)
  over `EXTRA_TOOLS`. Only tools with no backend (currently `kiro-cli`) belong
  in `EXTRA_TOOLS`.
- Image tag is `fenix-base:local` for the documented local build.
- Provisioning is non-fatal; failures are reported via status markers and
  `~/.provisioned/`, not hidden (see `docs/DESIGN.md`).
- Conventional Commits drive release-please (feat/fix/chore/ci/...).

## Verify before done

- `bash -n` on changed shell scripts; validate YAML/TOML; `hadolint` the
  Dockerfile.
- Let CI build the image and assert the entrypoint plus one `[tools]` and one
  `EXTRA_TOOLS` package provision and resolve.
- No stale legacy naming or root-`compose.yaml`/`mise.toml` references after
  structural changes.
- Changes land via branches/PRs; releases are automated from `main`.
