# Design

How the base image and a capsule behave at runtime. For the compact overview
see [`README.md`](../README.md); for declaring tools see [`TOOLS.md`](TOOLS.md).

## Base image

`ubuntu:24.04`, non-root `dev` user (UID/GID 1000). It carries zsh +
Oh-My-Zsh + Powerlevel10k (baked into the image, so first boot needs no
network), `gh`, a gnome-keyring Secret Service vault, a headless `xclip`
shim, editors + pager (`vim`, `nano`, `less`), `tini` as PID 1 (reaps orphaned
processes, forwards signals), and **mise** (pinned, checksum-verified). No
language runtimes or cloud tools are baked in.

**Fonts are a host responsibility.** The image renders no glyphs; the terminal
emulator on the host does. Install a Nerd Font (e.g. MesloLGS NF) on the host
and select it in your terminal profile to get the Powerlevel10k icons. The
image ships no fonts.

## Provenance

The image records what it is and when it was built, injected as build-args
(`IMAGE_VERSION`, `SOURCE_COMMIT`, `BUILD_DATE`; `dev`/`unknown` for local
builds, real values injected by CI):

- **`/etc/capsule/info.json`** — the structured source of truth (version,
  commit, build date, base OS).
- **`CAPSULE_INFO`** env — a one-line human summary, shown on the login banner.
- **OCI image labels** (`org.opencontainers.image.version`/`.revision`/
  `.created`/`.source`) — inspectable from the host with `docker inspect`,
  no exec needed.

Run `capsule-info` inside a capsule to print the summary and the JSON.

## Repositories

A capsule can declare the git repos it works on and clone them with
`capsule-sync`:

- **`CAPSULE_REPOS`** in `compose.yaml` — space-separated `owner/repo`, cloned
  into `~/workspace/<repo>`.
- **`~/.capsule-repos`** manifest (optional, mounted) — one `url [dir] [branch]`
  per line for explicit target dir / branch. Only `https://` URLs are
  accepted.

`capsule-sync` clones over HTTPS using the `gh` credential helper, is
**idempotent** (an existing target dir is skipped, never pulled or reset), and
prints a per-repo `cloned|skipped|failed` line plus a summary. Git never prompts
for credentials (`GIT_TERMINAL_PROMPT=0`); a repo needing auth fails fast. The
entrypoint attempts it on start (non-blocking): public repos clone, anything
needing auth is reported. It runs again after `capsule-unlock` unlocks the
keyring, and manually after `gh auth login`. It never blocks or fails container
start.

## Health

A `HEALTHCHECK` reads `~/.provisioned/status`: the container is **healthy** when
there is no `mise.toml` to provision (status file absent) or provisioning
finished cleanly (`rc=0`), and **unhealthy** when provisioning finished with a
failure. Because provisioning is non-fatal, a degraded container stays up and
is visible as `unhealthy` in `docker ps` rather than crash-looping.

## Provisioning

`provision.sh` is the single, re-runnable provisioning entry point. The
entrypoint calls it on start; it runs `mise install` then `extra-tools.sh`.

Provisioning is **non-fatal**: a tool that fails to install no longer stops the
container from starting — the environment always comes up, and the failure is
reported instead of hidden. Re-run it any time with `provision.sh`.

- **Status markers** (greppable in the logs): `mise: ok|failed`, one
  `extra-tool: <name>[@<ver>]: ok|failed|unknown` line per tool, a summary
  `extra-tools: summary ok=N failed=M (failed: ...)`, and
  `provision: summary mise=... extra-tools=...`.
- **Report**: full output and a one-line status are written to
  `~/.provisioned/last-run.log` and `~/.provisioned/status`.
- **Strict mode**: set `EXTRA_TOOLS_STRICT=1` to make `extra-tools.sh` exit
  non-zero when any tool fails (default is non-fatal).

## Prompt, window title, and iTerm2 profile

The zsh prompt uses the Powerlevel10k rainbow style. Terminal window and tab
titles are prefixed with the capsule name and current directory, e.g.
`[capsule:example] ~/workspace` (updates on `cd`). Set
`CAPSULE_NAME` in the capsule's `compose.yaml` to control the label; it falls
back to the container hostname when unset. On exit the title is cleared.

On an interactive shell the image switches to the devcontainer iTerm2 profile
via an OSC 1337 escape and restores the default on exit. Profile names are set
with `ITERM_DEVCONTAINER_PROFILE` (default `fenix-devcontainer`) and
`ITERM_DEFAULT_PROFILE` (default `fenix`); create matching iTerm2 profiles. Set
`CAPSULE_ITERM_PROFILE_SWITCH=0` to opt out. Other terminals ignore the escape.

## Welcome text

Show a message at login, two ways:

- **Simple:** `CAPSULE_WELCOME` in `compose.yaml` — a one-line banner.
- **Rich:** mount a plain text file at `/home/dev/.capsule-welcome` (printed
  verbatim, never executed); multi-line is fine. Control characters other than
  tab and newline are stripped from both, so the text cannot send terminal
  escape sequences.

## Credentials and the keyring

The entrypoint starts a D-Bus session and writes its environment to
`~/.keyring-env`, sourced by shells and by the `gh` wrapper. gnome-keyring is
not started at boot and is never D-Bus-autostarted; `capsule-unlock` starts it
with the user's password. No credentials live in the image or repo; they
persist in the home volume.

**Keyring password.** The keyring file (`~/.local/share/keyrings/login.keyring`)
is encrypted with a password the user chooses:

- **First interactive shell** after each container start runs `capsule-unlock`:
  on a fresh volume it asks for a new password (with confirmation); afterwards
  it asks for that password. Empty passwords are refused. Three failed attempts
  leave the keyring locked; run `capsule-unlock` to retry. Set
  `CAPSULE_KEYRING_PROMPT=0` to skip the prompt at shell start.
- **Unattended:** if `/run/secrets/keyring_password` (or `KEYRING_PASSWORD_FILE`)
  exists and is readable by UID 1000, the entrypoint unlocks with it at start
  (compose `secrets:`; see
  [`example/compose.yaml`](../example/compose.yaml)). The password then lives
  on the host in that file.
- **Volumes from older images** hold a keyring with no real password.
  `capsule-unlock` detects it and offers a reset: the keyring is deleted (stored
  tokens are lost; sign in again) and a new password is set. Declining keeps it
  unlocked as before. A password file never unlocks such a keyring.
- **No plaintext fallback.** With the keyring locked, `gh` would store its token
  in plaintext `~/.config/gh/hosts.yml`. The `gh` wrapper refuses `gh auth
  login`/`refresh` while the keyring is locked unless `--insecure-storage` is
  passed. `capsule-unlock` warns when `hosts.yml` already holds a token; move
  it with `gh auth logout` then `gh auth login`.
- After unlocking, `capsule-unlock` runs `capsule-sync` when repos are declared.
  `capsule-unlock --status` reports `unlocked` or `locked`.

**AWS config.** Two non-secret ways to configure the AWS CLI; tokens always
come from `aws sso login` into the home volume, never from the repo or image.

- **Env seeding.** If the non-secret `AWS_SSO_START_URL` and `AWS_SSO_REGION`
  are set (plus optional `AWS_SSO_SESSION`/`AWS_SSO_ACCOUNT_ID`/`AWS_SSO_ROLE_NAME`/
  `AWS_REGION`/`AWS_PROFILE`/`AWS_DEFAULT_OUTPUT`) and `~/.aws/config` does not
  yet exist, the entrypoint writes an `[sso-session]` + profile block —
  mirroring how it handles `GIT_USER_*`. A fresh volume then needs only
  `aws sso login`; no `aws configure sso`. The logic is generic and a no-op when
  the vars are unset or a config already exists; only non-secret identifiers
  come from the capsule.
- **Mounted file.** Mount a prewritten `~/.aws/config` read-only at
  `/home/dev/.aws/config`. Because the env seeding is guarded by
  `[ ! -f ~/.aws/config ]`, a mounted config takes precedence and the env path
  is a no-op. This is the natural source of truth when you need multiple
  profiles or sso-sessions; keep it non-secret (identifiers only).

## Version pinning

- **Base image** pins the `ubuntu:24.04` digest, mise (version + checksum),
  oh-my-zsh and powerlevel10k (commit SHAs), and the `gh` apt key
  fingerprints. Ubuntu packages and `gh` come from signed apt repos at build
  time. Rebuild with `./build-images.sh` to pick up changes.
- **`mise.toml`** pins each tool version; `mise.lock` and `.mise/locks/`
  (mounted beside it)
  pins checksums where the backend provides them (see [`TOOLS.md`](TOOLS.md)).

Upgrade deliberately by rebuilding the base image and/or bumping versions.
