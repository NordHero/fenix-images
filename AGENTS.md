# AGENTS.md

Guidance for AI agents working in this repo. This is the single agent-facing
doc; everything else is written for humans.

## Hard rules

1. **No comments in code files.** Dockerfiles and shell scripts contain plain
   code only (shebang allowed). Put explanations in docs, not inline.
2. **Docs are compact and factual.** State what is. Omit history, decision
   narration, and verbose justification. The one exception is
   [`docs/IMAGES.md`](docs/IMAGES.md), which deliberately records the structure
   rationale and rejected alternatives; keep the *why* there and link to it
   from other docs rather than repeating it.
3. **No secrets.** Credentials never live in the image or the repo; they stay in
   the home volume (`/home/dev`) at runtime, authenticated by the user.
4. **No AI attribution.** Commit messages and PR descriptions carry no
   `Co-Authored-By`, "Generated with", or other trailers naming Claude,
   Anthropic, Kiro, Copilot, or any AI tool.

## Project

**fenix-images** builds a single, minimal non-root development base image and
layers optional cloud CLIs, coding agents and [mise](https://mise.jdx.dev) on
top via multi-stage targets, and ships a sample capsule. It is self-contained:
usable with nothing but `docker compose`.

Tools are **not** baked per image; less critical tools are declared in a
`mise.toml` and installed into the home volume on first boot (when the `mise`
target is used). A **capsule** is a folder with `compose.yaml` + `mise.toml`
defining one encapsulated runtime; **capsules** is the plural.

The documented flow is self-contained and build-it-yourself: users clone this
repo, build the image locally (`./build-images.sh` -> `fenix-base:local`,
default target `mise`), and reference that local image or `build:` it from
their capsules. No image is published.

## Where things live

- `Dockerfile` — multi-stage image, targets `base` → `cloud-ops` → `agents` →
  `mise` (base is OS + eye-candy; mise is the last layer). Root context.
- `base/cloud-ops.sh`, `base/agents.sh` — per-target dispatchers; no-op when
  their selection (`CLOUD_CLIS` / `CODING_AGENTS`) is empty. `cloud-ops.sh`
  delegates to `capsule-tools`.
- `vendor/` — the `capsule-tools` framework (`capsule-tools.sh`) and one file
  per build-time-installed tool under `vendor/tools/<name>.sh` (channel, pinned
  version/anchor, update model, install function). Verification is fatal; an
  unknown tool or wrong anchor fails the build. Currently `aws`, `gcloud`, `az`,
  `claude-code`, `copilot`, `kiro-cli`, `gemini`. `vendor/gemini/` holds the
  committed npm lockfile the `gemini` agent installs with `npm ci`.
- `base/start.d/`, `base/zshrc.d/` — hook/snippet dirs run by the entrypoint and
  sourced by zshrc; `10-mise.*` live in the `mise` target, `20-updates.sh`
  (the `capsule-updates` refresh hook) in `base`.
- `base/` — files copied into the image (entrypoint, provision, zshrc, p10k,
  `gh` wrapper, `capsule-unlock`,
  xclip shim, `capsule-info`, `capsule-sync`, `capsule-git`, `capsule-updates`). Provenance (`IMAGE_VERSION`/`SOURCE_COMMIT`/
  `BUILD_DATE` build-args) is written to `/etc/capsule/info.json`, the
  `CAPSULE_INFO` env, and OCI image labels. `capsule-updates` reports pending
  apt security updates and image age (notify-and-rebuild; no runtime upgrades).
  `capsule-git` validates
  `~/.capsule-git.yaml` (git identity + repos) and applies the identity on
  start; `capsule-sync` clones its repos idempotently via the gh credential
  helper.
- `schema/` — `git.schema.json`, the JSON Schema for `git.yaml`. Keep it and
  the runtime checks in `base/capsule-git.sh` in step.
- `build-images.sh` — builds the Dockerfile and tags it `fenix-base:local`
  (`REGISTRY=fenix`, `TAG=local` by default).
- `example/` — the shipped example capsule (`compose.yaml` + `mise.toml`). It
  is the canonical default: a clean, copy-me template and the reference CI
  boots to confirm the model works. `example/mise.toml` is intentionally
  minimal (a single declared tool); keep it simple — richer toolsets belong in
  consumers' own capsules, not here.
- `docs/` — human depth: `IMAGES.md` (image structure, rationale, and choosing a
  configuration — the one doc that keeps the *why*), `DESIGN.md` (runtime
  behavior), `TOOLS.md` (declaring tools in `mise.toml`).
- `.github/workflows/` — `build-images.yml` (PR/main: path classification,
  config + lock check, build + verify + scan, calls `verify-example.yml`, and
  the always-run `ci-ok` gate required on `main`),
  `release-please.yml` (version PRs + tags/CHANGELOG; dispatches CI on the
  release branch),
  `scheduled-rebuild.yml` (weekly no-cache rebuild + Trivy scan; no publish),
  `close-external-prs.yml` (closes fork PRs from non-members),
  `tool-version-check.yml` (daily; runs `.github/scripts/bump-tools.sh` to keep
  one self-updating version-bump PR per pinned tool; never touches trust
  anchors).
- `.github/scripts/` — CI-only helper scripts (`bump-tools.sh`,
  `check-single-python.sh`, `image-size-report.sh`).

There is no root `compose.yaml` or root `mise.toml`; the example capsule is the
single reference.

## Trust

mise and its tool backends are the trust point for `[tools]`: declared tools are
resolved and verified by mise (pinned + checksum-verified mise, Sigstore/SLSA
provenance, `mise lock` digests). A `mise.toml` with `[env]` is untrusted until
trusted; provisioning skips the mounted `mise.toml` until it is trusted
(`CAPSULE_TRUST_MISE=1` or a manual `mise trust`). To stop a `[tools]` entry
from shadowing a verified cloud/agent tool, `provision.sh` refuses entries
matching the `capsule-tools` registry (`mise: denied <name>`), mise shims sit
after the system paths on `PATH`, and `capsule-info` reports each registered
tool's origin. This is best-effort: `npm i -g` / `pip install` still bypass it.

Coding agents (`agents` layer) are installed at build time by `capsule-tools`
against a pinned anchor (claude-code, copilot and kiro-cli are checksum-only;
gemini uses npm integrity hashes over GPG-verified Node). They may self-update
afterwards: the verified build-time install is the seed and a home copy wins on
`PATH`. See `SECURITY.md`.

## Conventions

- Image layering invariants (rationale in [`docs/IMAGES.md`](docs/IMAGES.md)):
  no mise below the `mise` target; no Node anywhere except the opt-in `gemini`
  agent's own path; exactly one Python on `PATH` (`/usr/bin/python3`, az's
  bundled interpreter stays off `PATH`); a tool belongs in `cloud-ops`/`agents`
  only if it is **critical** (stores credentials or acts autonomously),
  otherwise it goes through mise `[tools]`; trust anchors (keys, fingerprints,
  checksums-as-anchors) change only by human review in a PR, never by the
  automated version bump.
- Every environment variable the image or its scripts read is listed in
  `docs/DESIGN.md` under "Environment variables"; add or update its row in the
  same change.
- Non-root `dev` user (UID/GID 1000); home at `/home/dev`.
- After changing `example/mise.toml`, run `mise lock` in `example/` and commit
  `mise.lock` and `.mise/locks/`; CI fails on drift. Never use `"latest"`.
- Tool versions are pinned in `mise.toml` (`[tools]`) or in the tool file under
  `vendor/tools/` for cloud CLIs and agents.
- Prefer a `[tools]` backend (`pypi:`, `aqua:`, `go:`, `ubi:`, `vfox:`, ...) for
  developer tools; cloud CLIs and coding agents go in the `cloud-ops`/`agents`
  layers via `capsule-tools`.
- Image tag is `fenix-base:local` for the documented local build.
- Provisioning is non-fatal; failures are reported via status markers and
  `~/.provisioned/`, not hidden (see `docs/DESIGN.md`).
- Conventional Commits drive release-please (feat/fix/chore/ci/...).

## Verify before done

- `bash -n` on changed shell scripts; validate YAML/TOML; `hadolint` the
  Dockerfile.
- Let CI build the image and assert the entrypoint plus one `[tools]` package
  provision and resolve.
- No stale legacy naming or root-`compose.yaml`/`mise.toml` references after
  structural changes.
- Changes land via branches/PRs; releases are automated from `main`.
