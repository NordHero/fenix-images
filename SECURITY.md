# Security

## Secret-free by design

This repo builds a development base image; it must stay **secret-free**. No
passwords, tokens, or credentials are committed, and none are baked into the
image. All sign-ins are manual and performed by the user at runtime inside a
capsule (e.g. `gh auth login`, `aws sso login`, or any other CLI you declare).
Credentials live in the capsule's home volume (`/home/dev`), never in the image
or this repository.

## Stored credentials

Docker does not encrypt volumes. What protects a credential depends on where it
is stored:

| Credential | Stored in | Protected by |
|---|---|---|
| `gh` token | gnome-keyring in the home volume | keyring password + host disk encryption |
| other CLI credentials (e.g. `~/.aws`) | files in the home volume | host disk encryption only |
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
- Pin every version in a capsule's `mise.toml` and commit a `mise.lock`
  (`mise lock`): it records checksums for registry and `aqua:` tools, and mise
  rejects a download that does not match. (Other backends lock differently:
  `pypi:` tools get a hash-locked uv lockfile under `.mise/locks/`, `go:`
  modules are verified by the Go checksum database, and other version-only
  backends (`ubi:`, some registry tools) are pinned by version only.) The
  shipped `example/` is a clean template (`mise.toml` only) — lock it in your
  own copy.

The cloud CLIs in the `cloud-ops` layer (`aws`, `gcloud`, `az`) are a
**higher trust tier**: each is installed at build time from the vendor's own
channel and verified against an anchor pinned in `vendor/tools/<name>.sh`
(`aws` by the AWS CLI Team PGP signature; `gcloud` and `az` by their apt signing
key fingerprints). Verification is fatal — a tampered download or a wrong
anchor fails the build. Anchors change only by human review of a PR.

The coding agents in the `agents` layer (`claude-code`, `copilot`, `kiro-cli`,
and opt-in `gemini`) are installed at build time from each vendor's channel and
verified against an anchor pinned in `vendor/tools/<name>.sh`. `claude-code`,
`copilot` and `kiro-cli` are **checksum-only** (the vendors publish no
signature or attestation we can verify; the binary is checked against the
SHA-256 the vendor serves over TLS); `gemini` uses npm integrity hashes over a
Node runtime verified by its GPG-signed `SHASUMS256.txt.asc`. Verification is
fatal at build time. Agents are then allowed to **self-update**: the verified
build-time install is a seed under `/opt/capsule/agents/<name>`, and a
dev-writable home copy wins on `PATH`. This trades tamper resistance for
staying current; a self-updated agent is no longer described by our pins or the
image scan.

To keep these verified copies authoritative in the `mise` target, `provision.sh`
refuses `[tools]` entries that match the `capsule-tools` registry (reported as
`mise: denied <name>`), mise shims sit after the system paths on `PATH`, and
`capsule-info` surfaces any leftover mise copy shadowing a verified tool. This
is a best-effort guard rail, not a security boundary: a dev can still bypass it
with `npm i -g`, `pip install`, or a manual download.

### Per-tool channel and anchor strength

| Tool | Layer | Channel | Anchor | Self-update |
|---|---|---|---|---|
| `aws` | cloud-ops | signed source release | **signature** (AWS CLI Team PGP) | no |
| `gcloud` | cloud-ops | Google apt repo | **apt signature** (pinned key fingerprint) | no |
| `az` | cloud-ops | Microsoft apt repo | **apt signature** (pinned key fingerprint) | no |
| `claude-code` | agents | `downloads.claude.ai` | **checksum-only** (pinned, TLS manifest) | yes |
| `copilot` | agents | `github/copilot-cli` release | **checksum-only** (pinned `SHA256SUMS.txt`) | yes |
| `kiro-cli` | agents | `prod.download.cli.kiro.dev` | **checksum-only** (pinned, TLS manifest) | yes |
| `gemini` | agents | npm (`npm ci` from committed lockfile) | **npm integrity** over **GPG-signed** Node | yes |

Checksum-only means the vendor publishes no signature or attestation we can
verify; the binary is checked against the SHA-256 the vendor serves over TLS and
pinned in this repo. The self-updating agents trade tamper resistance for
staying current (see above). The cloud CLIs do not self-update; they refresh via
a bump PR plus a rebuild.

**One Python on `PATH`.** Exactly one interpreter is on `PATH`, Ubuntu's
`/usr/bin/python3`. `az` bundles its own interpreter but keeps it in `/opt/az`,
off `PATH` (the one allowed exception); gcloud's bundled interpreter is excluded
at install. CI asserts this. **Node** is installed only for the opt-in `gemini`
agent, off `PATH` under `/opt/gemini/node`; its npm dependency tree is pinned by
a committed lockfile with integrity hashes.

The rationale for all of this — threat model, layering, channel preference, the
self-update and one-Python decisions, and the alternatives rejected — is in
[`docs/IMAGES.md`](docs/IMAGES.md).

## Build inputs

| Input | Pinning |
|---|---|
| `ubuntu:24.04` base | digest (updated by Dependabot) |
| Ubuntu packages | latest from Ubuntu's signed apt repos at build time |
| `gh` | latest from GitHub's apt repo; the repo key is checked against pinned fingerprints |
| mise | version + SHA-256 |
| yq | version + per-architecture SHA-256 (`YQ_VERSION`, `YQ_SHA256_AMD64`, `YQ_SHA256_ARM64` build-args) |
| oh-my-zsh, powerlevel10k | commit SHA (`OHMYZSH_COMMIT`, `POWERLEVEL10K_COMMIT` build-args) |
| GitHub Actions | commit SHA (updated by Dependabot) |

Workflows use least-privilege permissions. Bump the oh-my-zsh and
powerlevel10k commits and yq deliberately; Dependabot does not track them.
For yq, take the SHA-256 of `yq_linux_amd64` and `yq_linux_arm64` from the
release's `checksums` file and confirm it against the downloaded binaries.

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

A daily **tool version check** (`.github/workflows/tool-version-check.yml`)
compares each pinned tool version against its latest upstream release and
maintains one self-updating pull request per tool to bump it, so security
releases are surfaced promptly. It bumps version/checksum pins only and never
changes a trust anchor; key rotation is a human-reviewed change.

## Reporting a vulnerability

Open a private security advisory via GitHub's "Report a vulnerability" on this
repository. Please do not file public issues for security reports.
