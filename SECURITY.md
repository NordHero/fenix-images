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

## Container

- The image has no `sudo`; everything runs as `dev`. The example capsule also
  sets `cap_drop: [ALL]` and `no-new-privileges:true`; copy both into your
  capsules.
- git's ownership check stays on. The home volume and `~/workspace` are owned
  by `dev`. For a bind mount owned by another UID, allow that path only:
  `git config --global --add safe.directory /path/to/repo`. The entrypoint
  removes a `safe.directory "*"` left by older images.

## Trust model

A capsule's `mise.toml` is code, not data: its `[env]`, hooks and tool choices
run as `dev`. Provisioning skips a mounted `mise.toml` until it is trusted,
either by `CAPSULE_TRUST_MISE=1` (trusted on start, no prompt) or by a manual
`mise trust ~/mise.toml`. Only trust a `mise.toml` you would run as a script.
Running `mise install` by hand also trusts the config (mise's own behaviour).

mise and its backends are the trust point for `[tools]`:

- mise itself is installed at a pinned version, SHA-256-verified at build time.
- `example/mise.toml` pins its version. `example/mise.lock` records checksums
  for registry and `aqua:` tools; mise rejects a download that does not match.
  (Other backends lock differently: `pypi:` tools get a hash-locked uv
  lockfile under `.mise/locks/`, `go:` modules are verified by the Go checksum
  database, and `awscli`/`gcloud`/`ubi:` entries are pinned by version only.)
  CI fails when the lock is out of date.

`EXTRA_TOOLS` are a **separate, lower trust tier**: tools with no mise backend,
installed by the vendor's own script. The base image supports `kiro-cli`, whose
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
`verify-example` installs the example capsule's declared tools, copies
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

A daily **mise version check** (`.github/workflows/mise-version-check.yml`)
compares the pinned `MISE_VERSION` against the latest mise release and maintains
a single self-updating pull request to bump it, so security releases are
surfaced promptly.

## Reporting a vulnerability

Open a private security advisory via GitHub's "Report a vulnerability" on this
repository. Please do not file public issues for security reports.
