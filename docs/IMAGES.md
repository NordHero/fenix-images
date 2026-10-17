# Image structure and configuration

How the image is layered, why it is layered that way, and how to choose a
configuration for a capsule. For runtime behavior see
[`DESIGN.md`](DESIGN.md); for declaring developer tools see
[`TOOLS.md`](TOOLS.md); for the trust model see [`SECURITY.md`](../SECURITY.md).

Unlike the rest of the docs, this file explains *why* — it is the exception to
the "omit justification" rule in [`AGENTS.md`](../AGENTS.md).

## Why the structure is as it is

### Threat model

Cloud CLIs and coding agents are **critical tools**: they either store
credentials themselves (SSO/token caches) or act on them autonomously. A
compromised or tampered build of one of these runs with the capsule's cloud and
source-control access. Everything else — compilers, linters, language runtimes,
IaC binaries — consumes credentials a human or a cloud CLI already produced and
is run by a human. The structure follows from protecting the critical tools
without making the rest heavier than it needs to be.

### mise is not in `base`, and sits last

mise and its backends are a single trust point for everything they install. If
mise were in the base image, every capsule would inherit that trust point even
when it installs nothing through mise. So mise is the **last, optional layer**:
a capsule opts into it only when it declares `[tools]`. Critical tools never
come through mise (see below), so the trust point covers only developer tools
the dev chose.

### Separate layers, built from vendor channels

The `Dockerfile` is multi-stage, built in a fixed order where each layer is a
no-op when its selection is empty:

```
ubuntu:24.04@sha256:…
 └─ base        OS + security updates, dev user, zsh, git, gh, yq, python3, capsule-*
    └─ cloud-ops   ARG CLOUD_CLIS="aws gcloud az"                 (any subset)
       └─ agents   ARG CODING_AGENTS="claude-code copilot kiro-cli gemini"  (any subset; gemini adds Node)
          └─ mise  optional; developer tools via [tools]
```

Cloud CLIs and agents are installed **at build time** by the `capsule-tools`
framework, each from the vendor's own recommended channel and verified against
an anchor pinned in `vendor/tools/<name>.sh`. Verification is fatal: a failed
signature or checksum, or an unknown tool, breaks the build, and CI exercises
every entry on amd64 and arm64. Anchors change only by human review of a PR; the
automated version bumps touch versions and checksums, never a trust anchor.

### Channel preference and anchor strength

Channels are chosen in this order of preference:

1. a vendor apt repo with a pinned signing key;
2. release artifacts with a vendor signature or attestation;
3. a release binary with a vendor checksum, pinned in this repo and marked
   checksum-only.

Never `curl | bash`. The resulting anchor strengths differ per tool; the
[per-tool table](#per-tool-reference) and [`SECURITY.md`](../SECURITY.md) record
exactly what each one is.

### Self-update trade-off (agents)

Agents may self-update: the verified build-time install is a **seed** under
`/opt/capsule/agents/<name>`, and a dev-writable home copy in `~/.local/bin`
wins on `PATH` afterwards. Running a stale agent is worse than the trade-off, so
self-update is allowed — but it gives up tamper resistance (an agent binary in a
dev-writable path can be replaced and survives rebuilds) and means a running
agent is no longer described by our pins or the image scan. Cloud CLIs do not
self-update; they refresh through a bump PR plus a rebuild.

### No Node, except opt-in gemini

Node is a large runtime and dependency surface. It is installed **only** in the
`agents` layer and **only** when `gemini` is selected, from a GPG-verified
nodejs.org tarball into `/opt/gemini/node`, off `PATH`; only a `gemini` wrapper
is on `PATH`. Copilot embeds its own runtime, so it needs no system Node. No
other layer installs Node.

### One Python on `PATH`, with the az exception

`aws` and `gcloud` need a Python interpreter on `PATH`, and `pypi:` locking
assumes one. The image keeps exactly one on `PATH`: Ubuntu's `/usr/bin/python3`
(3.12). A vendor that bundles its own interpreter is allowed only when no
verified alternative exists and the interpreter is updated through the same
signed apt channel and kept **off** `PATH` — currently only `az`, whose
interpreter lives in `/opt/az`. gcloud's bundled interpreter is excluded at
install and pinned to the system Python with `CLOUDSDK_PYTHON`. CI asserts a
single interpreter on `PATH`.

### Ubuntu's Python over newer builds

Ubuntu's 3.12 is kept over python.org or standalone builds: Canonical patches it
through apt, `capsule-updates` covers it, and 3.12 has upstream security support
until 2028-10. A python.org/standalone build would move CPython patch tracking
onto us, outside the update check. A newer Python means a newer Ubuntu base,
which is a separate decision.

### IaC and cluster tools come via mise

terraform, opentofu, terragrunt, kubectl and helm are **not** critical tools:
they consume credentials from the cloud CLIs rather than storing their own, are
run by a human, and need per-project versions that mise provides per directory
and an image layer cannot. Their larger supply-chain surface (providers, charts)
is verified by their own mechanisms (provider signatures,
`.terraform.lock.hcl`) regardless of how the binary is installed. So they come
through mise, with these requirements: pin the version and commit `mise.lock`;
prefer a backend that verifies signatures or attestations over a checksum-only
one; commit `.terraform.lock.hcl`. Revisit if a team standardizes on one version
or a tool starts storing long-lived credentials — HashiCorp, OpenTofu and
pkgs.k8s.io all publish signed apt repos, so a `cloud-ops`-style entry would be
cheap.

### Update by rebuild

Capsules do not `apt upgrade` at runtime (non-root, `cap_drop: ALL`,
`no-new-privileges`), and an in-container upgrade would be lost on recreate.
`capsule-updates` reports pending apt security updates and the image age; the fix
is always a rebuild. See [`DESIGN.md`](DESIGN.md#os-updates).

### Alternatives considered

| Option | Why not |
|---|---|
| Coding agents via mise | mise and its registry/backends would become the trust point for autonomous, credential-holding tools — the opposite of this design; verification would run at runtime per volume, non-fatal and unscanned; self-update would desync from `mise.lock`; kiro-cli has no backend. Agents not in the registry may still come from mise at the dev's own risk. |
| Everything via mise + `mise.lock` | Fewest changes, but mise stays the single trust point for critical tools. |
| Bake everything root-owned, no self-update | Strongest tamper resistance, but agents go stale. |
| Verified install into the home volume at runtime | No build step, but verification runs per volume, unscanned and non-fatal. |
| IaC/cluster tools in their own verified layer | One version per image conflicts with per-project versions, protects only the binary (providers/charts dominate), and adds size and maintenance. |
| Python from python.org / standalone | Newer version, but we own CPython patch tracking, outside the update check. |

## Choosing a configuration

A capsule picks a **target** and, for `cloud-ops`/`agents`, a space-separated
**selection**, in its `compose.yaml`:

```yaml
build:
  context: <fenix-images checkout>
  target: mise            # base | cloud-ops | agents | mise
  args:
    CLOUD_CLIS: "aws"
    CODING_AGENTS: "claude-code"
```

Decision guide:

- Need only the base shell + git + `gh`? → `target: base`.
- Need cloud CLIs? → `target: cloud-ops`, set `CLOUD_CLIS`.
- Need coding agents? → `target: agents`, set `CODING_AGENTS` (and `CLOUD_CLIS`
  if you also want cloud CLIs — the layers stack).
- Need developer tools from `mise.toml` (languages, IaC, cluster tools)? →
  `target: mise`. This is the default and the richest; it includes every lower
  layer's selection.

Each target includes the layers below it, so `target: mise` with
`CLOUD_CLIS="aws"` and `CODING_AGENTS="claude-code"` yields base + aws +
claude-code + mise.

### Per-tool reference

| Tool | Layer | Channel | Anchor strength | Update model | ~Size |
|---|---|---|---|---|---|
| `aws` | cloud-ops | signed source release + build (`system-sandbox`) | vendor PGP signature | bump PR + rebuild | ~0.9 GB (incl. build deps) |
| `gcloud` | cloud-ops | Google apt repo | pinned apt key fingerprint | apt + rebuild | ~0.45 GB |
| `az` | cloud-ops | Microsoft apt repo | pinned apt key fingerprint | apt + rebuild | ~0.75 GB |
| `claude-code` | agents | `downloads.claude.ai` native release | checksum-only (pinned) | self-update | ~0.35 GB |
| `copilot` | agents | `github/copilot-cli` release binary | checksum-only (pinned) | self-update | ~0.6 GB |
| `kiro-cli` | agents | `prod.download.cli.kiro.dev` release | checksum-only (pinned) | self-update | ~0.45 GB |
| `gemini` | agents | `npm ci` from committed lockfile, on GPG-verified Node | npm integrity + Node GPG signature | self-update | ~0.5 GB |

Developer tools (`[tools]` in `mise.toml`) are a third tier; see
[`TOOLS.md`](TOOLS.md).

### Standard profiles

Reusing a few selections keeps the number of distinct images — and the disk they
consume — down. Suggested profiles:

| Profile | `target` | `CLOUD_CLIS` | `CODING_AGENTS` |
|---|---|---|---|
| minimal | `mise` | — | — |
| cloud-ops | `mise` | `aws gcloud az` | — |
| agent | `mise` | `aws` | `claude-code` |
| full | `mise` | `aws gcloud az` | `claude-code copilot kiro-cli` |

Example `compose.yaml` for the "agent" profile:

```yaml
services:
  dev:
    build:
      context: ../fenix-images
      target: mise
      args:
        CLOUD_CLIS: "aws"
        CODING_AGENTS: "claude-code"
    image: fenix-base:local
    volumes:
      - home:/home/dev
      - ./mise.toml:/home/dev/mise.toml:ro
    cap_drop: [ALL]
    security_opt: [no-new-privileges:true]
volumes:
  home:
```

### Size and rebuild consequences

- Each distinct selection is a separate image on top of the shared base; a
  handful of differently configured capsules can take 10–20 GB. Share a profile
  across capsules so they share layers, and run `docker image prune` to reclaim
  superseded layers (see [`TOOLS.md`](TOOLS.md#reclaiming-disk)).
- A base security update invalidates every layer above it; an all-in rebuild
  re-downloads on the order of a gigabyte.
- Self-updated agent versions accumulate in the home volume (each claude-code is
  ~285 MB); prune old versions there too.
- First start is fast: no cloud/agent install happens on boot (only mise
  `[tools]`).

### mise vs a registry entry

Prefer a mise `[tools]` backend for any developer tool that has one. Request a
`cloud-ops`/`agents` registry entry only for a **critical** tool (stores
credentials or acts autonomously) that warrants a verified, build-time install.
