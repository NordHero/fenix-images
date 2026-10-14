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
4. **No AI attribution.** Commit messages and PR descriptions carry no
   `Co-Authored-By`, "Generated with", or other trailers naming Claude,
   Anthropic, Kiro, Copilot, or any AI tool.

## Project

**fenix-images** builds a single, minimal non-root development base image with
[mise](https://mise.jdx.dev) baked in, and ships a sample capsule. It is
self-contained: usable with nothing but `docker compose`.

Tools are **not** baked per image; they are declared in a `mise.toml` and
installed into the home volume on first boot. A **capsule** is a folder with
`compose.yaml` + `mise.toml` defining one encapsulated runtime; **capsules** is
the plural.

The documented flow is self-contained and build-it-yourself: users clone this
repo, build the base image locally (`./build-images.sh` -> `fenix-base:local`),
and reference that local image from their capsules. No image is published.

## Where things live

- `Dockerfile` — the base image (OS + eye-candy + mise). Root context.
- `base/` — files copied into the image (entrypoint, provision, zshrc, p10k,
  `gh` wrapper, `capsule-unlock`,
  xclip shim, `capsule-info`, `capsule-sync`). Provenance (`IMAGE_VERSION`/`SOURCE_COMMIT`/
  `BUILD_DATE` build-args) is written to `/etc/capsule/info.json`, the
  `CAPSULE_INFO` env, and OCI image labels. `capsule-sync` clones repos declared
  in `CAPSULE_REPOS` / `~/.capsule-repos` idempotently via the gh credential helper.
- `extra-tools.sh` — installs tools with no mise backend (currently only
  `kiro-cli`); reads `EXTRA_TOOLS` from the mounted `mise.toml`. Cloud CLIs
  (azure-cli, copilot, gcloud) are declared in `[tools]` via mise backends.
- `build-images.sh` — builds the Dockerfile and tags it `fenix-base:local`
  (`REGISTRY=fenix`, `TAG=local` by default).
- `example/` — the shipped example capsule (`compose.yaml` + `mise.toml` +
  `mise.lock`). It
  is the canonical default: the reference used while developing the image and
  the target of CI's config validation. `example/mise.toml` is intentionally
  minimal (a single declared tool); keep it simple — richer toolsets belong in
  consumers' own capsules, not here.
- `docs/` — human depth: `DESIGN.md` (runtime behavior), `TOOLS.md` (declaring
  tools in `mise.toml`).
- `.github/workflows/` — `build-images.yml` (PR/main: path classification,
  config + lock check, build + verify + scan, calls `verify-example.yml`, and
  the always-run `ci-ok` gate required on `main`),
  `release-please.yml` (version PRs + tags/CHANGELOG; dispatches CI on the
  release branch),
  `scheduled-rebuild.yml` (weekly no-cache rebuild + Trivy scan; no publish),
  `close-external-prs.yml` (closes fork PRs from non-members).

There is no root `compose.yaml` or root `mise.toml`; the example capsule is the
single reference.

## Trust

mise and its tool backends are the trust point for `[tools]`: declared tools are
resolved and verified by mise (pinned + checksum-verified mise, Sigstore/SLSA
provenance, `mise lock` digests). A `mise.toml` with `[env]` is untrusted until
trusted; provisioning skips the mounted `mise.toml` until it is trusted
(`CAPSULE_TRUST_MISE=1` or a manual `mise trust`).

`EXTRA_TOOLS` are a **separate, lower trust tier**: vendor installers run over
TLS but are not checksum- or signature-verified by this repo. Do not claim
otherwise in docs. See `SECURITY.md`.

## Conventions

- Non-root `dev` user (UID/GID 1000); home at `/home/dev`.
- After changing `example/mise.toml`, run `mise lock` in `example/` and commit
  `mise.lock` and `.mise/locks/`; CI fails on drift. Never use `"latest"`.
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
