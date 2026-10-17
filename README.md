# fenix-images

A single, minimal, non-root **development base image** that layers optional
cloud CLIs, coding agents and [mise](https://mise.jdx.dev) on top via
multi-stage build targets, plus a ready-to-copy capsule template. You don't
build a custom image per project — you pick a target and declare the developer
tools you want in a `mise.toml`, and they are installed into the capsule's home
volume on first start.

> **Note:** mise is an **opt-in** supply-chain dependency — in the `mise`
> target, mise and its backends become a trust anchor for every developer tool
> a capsule installs through `[tools]`. Credential-bearing cloud CLIs and coding
> agents do not go through mise; they are built in from vendor channels against
> pinned anchors (see [`docs/IMAGES.md`](docs/IMAGES.md)). Weigh the mise trust
> anchor for your threat model. You can always build your own image instead:
> adapt the [`Dockerfile`](Dockerfile), or point a capsule's `build:`/`image:`
> at any image you build.

It is self-contained — usable with nothing but `docker compose`.

A **capsule** is an encapsulated development environment definition: a folder
with two declarative files, `compose.yaml` (image + volume) and `mise.toml`
(tools + versions). No scripts, no Dockerfile, nothing to maintain per project.

## How it works

```
This repo (clone + build once)         A capsule (a folder you own)
┌─────────────────────────────┐        ┌───────────────────────────────┐
│ Dockerfile: base → cloud-ops│        │ compose.yaml                  │
│   → agents → mise (targets) │◀───────│   build: { target: mise }     │
│ build-images.sh builds it   │  use   │   mounts ./mise.toml          │
│ -> fenix-base:local         │        │ mise.toml  (tools + versions) │
└─────────────────────────────┘        └───────────────────────────────┘
```

The base image is `ubuntu:24.04` with a non-root `dev` user, zsh +
Powerlevel10k, `gh`, a keyring vault, and editors; the `mise` target adds mise,
which installs the developer tools you declare into the home volume on first
boot (the volume persists, so later starts are instant). Optional `cloud-ops`
and `agents` layers add cloud CLIs and coding agents from verified vendor
channels. See [`docs/IMAGES.md`](docs/IMAGES.md) for the image structure and how
to choose a configuration, [`docs/DESIGN.md`](docs/DESIGN.md) for the full
runtime behavior, and [`docs/TOOLS.md`](docs/TOOLS.md) for declaring tools.

## Get started

Prerequisites: Docker (with the Compose plugin) and git. The capsule shell's
look depends on your host terminal: it needs a Nerd Font (e.g. MesloLGS NF),
which the image does not ship. If icons show as boxes or colors look wrong, see
[Host terminal requirements](docs/DESIGN.md#host-terminal-requirements).

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

### Git identity and repos

Declare the capsule's git identity and the repos it works on in
[`example/git.yaml`](example/git.yaml), mounted at `/home/dev/.capsule-git.yaml`.
It is validated against [`schema/git.schema.json`](schema/git.schema.json):

```yaml
version: 1
identity:
  name: Ada Lovelace
  email: ada@example.com
repos:
  fenix-images:
    url: https://github.com/NordHero/fenix-images.git
    branch: main
```

The identity is applied on every start. Clone the repos after authenticating:

```bash
gh auth login
capsule-sync          # clones declared repos into ~/workspace, skips existing
capsule-git check     # validates ~/.capsule-git.yaml
```

`capsule-sync` is idempotent (existing checkouts are never touched) and clones
over HTTPS via the `gh` credential helper. First boot attempts it automatically
for any public repos and prints a reminder for the rest.

### 3. Make it yours

Edit `example/mise.toml` to declare your tools (see
[`docs/TOOLS.md`](docs/TOOLS.md)), `example/git.yaml` for git identity and
repos, and `compose.yaml` to set `CAPSULE_NAME` and welcome text. All supported
variables are listed in
[`docs/DESIGN.md`](docs/DESIGN.md#environment-variables). Copy the folder per
project to keep each capsule self-contained.

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
