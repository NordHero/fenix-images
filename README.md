# fenix-images

A single, minimal, non-root **development base image** with
[mise](https://mise.jdx.dev) baked in, plus a ready-to-copy capsule template.
You don't build a custom image per project — you declare the tools you want in a
`mise.toml`, and they are installed into the capsule's home volume on first
start.

> **Note:** mise is a supply-chain dependency you opt into — mise and its
> backends become a trust anchor for everything a capsule installs. Weigh that
> for your threat model.

It is self-contained — usable with nothing but `docker compose`.

A **capsule** is an encapsulated development environment definition: a folder
with two declarative files, `compose.yaml` (image + volume) and `mise.toml`
(tools + versions). No scripts, no Dockerfile, nothing to maintain per project.

## How it works

```
This repo (clone + build once)         A capsule (a folder you own)
┌─────────────────────────────┐        ┌───────────────────────────────┐
│ Dockerfile: base + mise     │        │ compose.yaml                  │
│ extra-tools.sh (shim)       │◀───────│   image: fenix-base:local     │
│ build-images.sh builds it   │  use   │   mounts ./mise.toml          │
│ -> fenix-base:local         │        │ mise.toml  (tools + versions) │
└─────────────────────────────┘        └───────────────────────────────┘
```

The base image is `ubuntu:24.04` with a non-root `dev` user, zsh +
Powerlevel10k, `gh`, a keyring vault, editors, and mise. mise installs the tools
you declare into the home volume on first boot; the volume persists, so later
starts are instant. See [`docs/DESIGN.md`](docs/DESIGN.md) for the full runtime
behavior and [`docs/TOOLS.md`](docs/TOOLS.md) for declaring tools.

## Get started

Prerequisites: Docker (with the Compose plugin) and git. For the Powerlevel10k
prompt icons, install a Nerd Font (e.g. MesloLGS NF) on the host and select it
in your terminal — the image ships no fonts.

### 1. Clone and build the base image

```bash
git clone https://github.com/NordHero/fenix-images.git
cd fenix-images
./build-images.sh             # builds fenix-base:local
```

`build-images.sh` needs bash; on Windows run it from WSL or Git Bash, or run
`docker build -t fenix-base:local .` directly.

That local image is all your definitions reference — nothing is pulled from a
registry.

### 2. Run the example capsule

This repo ships a ready one at [`example/`](example/). Run it
as-is or copy it as a starting point:

```bash
cd example
docker compose up -d          # first boot provisions the volume (installs tools)
docker compose exec dev zsh   # work inside the capsule
docker compose down           # stop; the volume (your environment) is preserved
```

The first shell after each start asks for the keyring password (on a fresh
volume you set it), which encrypts stored tokens such as `gh`'s. Open more
shells in the same running capsule with another `docker compose exec dev zsh`.
Inside, authenticate the CLIs you declared (e.g. `gh auth login`; and once you
add them to `mise.toml`, `gcloud auth login`, `aws sso login`, `az login`) —
tokens persist in the home volume, never in the image or repo. See [Keyring password](docs/DESIGN.md#credentials-and-the-keyring)
for unattended unlock and volumes from older images.

For AWS, configure the CLI two ways (both non-secret; tokens still come from
`aws sso login` into the home volume):

- **Env (simple):** set the `AWS_SSO_*` identifiers in `compose.yaml`. On a
  fresh volume the entrypoint seeds `~/.aws/config`, so you only run
  `aws sso login` — no `aws configure sso`.
- **Mounted file:** mount your own prewritten `~/.aws/config` read-only at
  `/home/dev/.aws/config`. This supports multiple profiles/sso-sessions and
  takes precedence over the `AWS_SSO_*` env seeding.

See [`example/compose.yaml`](example/compose.yaml) for both.

### Clone your repos

Declare the repos a capsule works on with `CAPSULE_REPOS` in `compose.yaml`
(space-separated `owner/repo`), then clone them after authenticating:

```bash
gh auth login
capsule-sync          # clones declared repos into ~/workspace, skips existing
```

`capsule-sync` is idempotent (existing checkouts are never touched) and clones
over HTTPS via the `gh` credential helper. First boot attempts it automatically
for any public repos and prints a reminder for the rest. For per-repo target
dir/branch, mount a manifest at `/home/dev/.capsule-repos` (see
[`example/repos.txt`](example/repos.txt)).

### 3. Make it yours

Edit `example/mise.toml` to declare your tools (see
[`docs/TOOLS.md`](docs/TOOLS.md)) and `compose.yaml` to set `CAPSULE_NAME`, git
identity, and welcome text. Copy the folder per project to keep each capsule
self-contained.

## What this is not

- Not a per-project image builder — tools are declared in `mise.toml`, not baked
  into images.
- Not a registry-first flow — the documented path is build-it-yourself
  (`fenix-base:local`). No image is published for consumption.
- Not a host bootstrapper — it assumes Docker is already set up on the host.
- Not locked to mise — the way of working (minimal base + declarative, pinned
  per-capsule tools) is the point, not the tool. You can always build your own
  image without it.
- Not a place for project or customer content, cloud/AI work, or secrets.

## Developing this image

```bash
./build-images.sh             # -> fenix-base:local
cd example && docker compose up -d && docker compose exec dev zsh
```

The example capsule doubles as the reference used while developing the image.

## For contributors and agents

[`AGENTS.md`](AGENTS.md) lists conventions for AI agents. See
[`CONTRIBUTING.md`](CONTRIBUTING.md) for local setup and quality gates,
[`SECURITY.md`](SECURITY.md) for the trust model and how to report issues, and
[`LICENSE`](LICENSE) (MIT).
