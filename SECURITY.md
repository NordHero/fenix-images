# Security

## Secret-free by design

This repo builds a development base image; it must stay **secret-free**. No
passwords, tokens, or credentials are committed, and none are baked into the
image. All sign-ins are manual and performed by the user at runtime inside a
capsule (`gh auth login`, `gcloud auth login`, `aws configure`, `az login`).
Credentials live in the capsule's home volume (`/home/dev`), never in the image
or this repository.

## Trust model

mise and its tool backends are the trust point for everything declared in a
`mise.toml`:

- mise itself is installed at a pinned version with its SHA-256 checksum
  verified at build time; mise releases are Sigstore-signed with SLSA
  provenance.
- mise verifies the tools it installs, and `mise lock` records exact digests.
- A `mise.toml` that sets `[env]` is untrusted until trusted; the entrypoint
  trusts the mounted `mise.toml` on start.

`EXTRA_TOOLS` are a **separate, lower trust tier**: tools with no mise backend,
installed by the vendor's own script. Currently this is only `kiro-cli`, whose
installer verifies its own checksums but is not verified by mise or this repo.
Treat it as you would any `curl | bash` vendor installer; prefer a `[tools]`
backend whenever one exists. Most cloud CLIs (azure-cli, GitHub Copilot CLI,
gcloud) install through mise backends and gain mise's verification.

## Scanning

Every push and pull request is scanned in CI
(`.github/workflows/build-images.yml`):

- **Trivy** — the built base image is scanned for HIGH/CRITICAL OS and library
  vulnerabilities (`ignore-unfixed`), with results uploaded as SARIF.

A weekly **scheduled rebuild** (`.github/workflows/scheduled-rebuild.yml`)
rebuilds the image with `--no-cache --pull` and Trivy-scans it, surfacing newly
disclosed LTS base CVEs even when there are no code changes. No image is
published; rebuild locally with `./build-images.sh` to pick up the
patches a scan flags.

Shell scripts are linted and format-checked, and the Dockerfile is linted, via
pre-commit (`shellcheck`, `shfmt`, `hadolint`) and gitleaks for secrets.

## Supply-chain hardening

- The base is pinned to `ubuntu:24.04`; LTS security updates are applied at
  build time, and the weekly scheduled no-cache rebuild scans for newly
  disclosed base CVEs. Rebuild locally to apply the patches it flags.
- mise is pinned and checksum-verified before use.
- GitHub Actions are pinned; workflows use least-privilege permissions.

## Reporting a vulnerability

Open a private security advisory via GitHub's "Report a vulnerability" on this
repository. Please do not file public issues for security reports.
