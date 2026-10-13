# Security

## Secret-free by design

This repo builds a development base image; it must stay **secret-free**. No
passwords, tokens, or credentials are committed, and none are baked into the
image. All sign-ins are manual and performed by the user at runtime inside a
capsule (`gh auth login`, `gcloud auth login`, `aws sso login`, `az login`).
Credentials live in the capsule's home volume (`/home/dev`), never in the image
or this repository.

## Stored credentials

Docker does not encrypt volumes. What protects a credential depends on where it
is stored:

| Credential | Stored in | Protected by |
|---|---|---|
| `gh` token | gnome-keyring in the home volume | keyring password + host disk encryption |
| `gcloud`, `aws`, `az` credentials | files in the home volume | host disk encryption only |
| keyring password file (optional) | the host | host file permissions + disk encryption |

The keyring password (see
[`docs/DESIGN.md`](docs/DESIGN.md#credentials-and-the-keyring)):

- **Protects** copies of the volume (exports, backups, the Docker Desktop disk
  image) and a stopped container: the keyring file is unreadable without the
  password.
- **Does not protect** against processes in a running, unlocked capsule. Any
  process running as `dev` can read the keyring through the Secret Service
  API, and every file in the home volume.
- **Password file:** `/run/secrets/keyring_password` unlocks without a prompt
  but keeps the password on the host; that file plus a copy of the volume
  exposes the tokens.
- **No plaintext fallback:** `gh auth login`/`refresh` is refused while the
  keyring is locked, unless `--insecure-storage` is passed.

Host full-disk encryption (FileVault, BitLocker, LUKS) protects the volume at
rest while the host is off; it does nothing while the host is running.

Limit what a token can reach: prefer a fine-grained personal access token
scoped to the repositories a capsule works on (`gh auth login --with-token`)
over the broad default `gh` OAuth token.

## Trust model

A capsule's `mise.toml` is code, not data. The entrypoint trusts the mounted
`mise.toml` on start, so its `[env]`, hooks and tool choices run as `dev`
without a prompt. Only mount a `mise.toml` you would run as a script.

mise and its backends are the trust point for `[tools]`:

- mise itself is installed at a pinned version, SHA-256-verified at build time.
- `example/mise.toml` pins every version. `example/mise.lock` records
  checksums for registry and `aqua:` tools, and `example/.mise/locks/` holds a
  hash-locked uv lockfile per `pypi:` tool (the package and all its
  dependencies); mise rejects a download that does not match. `go:` modules
  are verified by the Go checksum database. `awscli`, `gcloud` and `ubi:`
  entries are pinned by version only. CI fails when the lock is out of date.

`EXTRA_TOOLS` are a **separate, lower trust tier**: tools with no mise backend,
installed by the vendor's own script. Currently this is only `kiro-cli`, whose
installer verifies its own checksums but is not verified by mise or this repo.
Treat it as you would any `curl | bash` vendor installer; prefer a `[tools]`
backend whenever one exists.

## Build inputs

| Input | Pinning |
|---|---|
| `ubuntu:24.04` base | digest (updated by Dependabot) |
| Ubuntu packages | latest from Ubuntu's signed apt repos at build time |
| `gh` | latest from GitHub's apt repo; the repo key is checked against pinned fingerprints |
| mise | version + SHA-256 |
| oh-my-zsh, powerlevel10k | commit SHA (`OHMYZSH_COMMIT`, `POWERLEVEL10K_COMMIT` build-args) |
| GitHub Actions | commit SHA (updated by Dependabot) |

Workflows use least-privilege permissions. Bump the oh-my-zsh and
powerlevel10k commits deliberately; Dependabot does not track them.

## Scanning

CI (`.github/workflows/build-images.yml`) builds the image on every pull
request and push to `main` and scans it with **Trivy** for HIGH/CRITICAL OS
and library vulnerabilities that have a fix (`ignore-unfixed`). Results from
`main` are uploaded to GitHub code scanning.

The tools mise installs live in the home volume, not the image.
`verify-example` installs the example capsule's full toolset, copies
`~/.local/share/mise/installs` and `~/.local/bin` out of the volume and scans
them with Trivy (`rootfs`, same severity filter). Results from `main`, the
weekly run and manual runs are uploaded under the `trivy-mise-tools`
category. Tools installed in your own capsules are not scanned; bump their
versions in `mise.toml` when a scan flags the same tool.

A weekly **scheduled rebuild** (`.github/workflows/scheduled-rebuild.yml`)
rebuilds the image without cache and scans it, surfacing newly disclosed CVEs
even when there are no code changes. No image is published; rebuild locally
with `./build-images.sh` to pick up the patches a scan flags.

`shellcheck`, `shfmt`, `hadolint` and `gitleaks` run locally as pre-commit
hooks (`.pre-commit-config.yaml`), not in CI.

## Reporting a vulnerability

Open a private security advisory via GitHub's "Report a vulnerability" on this
repository. Please do not file public issues for security reports.
