# Design

How the base image and a capsule behave at runtime. For the compact overview
see [`README.md`](../README.md); for declaring tools see [`TOOLS.md`](TOOLS.md).
All supported variables are listed under
[Environment variables](#environment-variables).

## Base image

`ubuntu:24.04`, non-root `dev` user (UID/GID 1000). It carries zsh +
Oh-My-Zsh + Powerlevel10k (baked into the image, so first boot needs no
network), `gh`, a gnome-keyring Secret Service vault, a headless `xclip`
shim, editors + pager (`vim`, `nano`, `less`), `tini` as PID 1 (reaps orphaned
processes, forwards signals), **mise** and **yq** (pinned, checksum-verified), and
`bubblewrap` + `socat` (the Linux backends for agent command sandboxes —
bubblewrap + seccomp is the shared mechanism used by Kiro, GitHub Copilot CLI
and Claude Code; installed but not enabled, and the base image ships no sandbox
policy). The only language runtime baked in is the distro Python (`python3`
plus a `python` symlink via `python-is-python3`): a system interpreter many
tool installers and `pypi:` locking assume on `PATH`. mise still owns pinned,
per-capsule Python versions; the baked one is the always-present baseline. No
other language runtimes or cloud tools are baked in.

## Host terminal requirements

The image runs the shell; the terminal emulator on the host draws it. For the
capsule shell to look as intended, the host terminal needs:

| Requirement | Used for | Without it |
|---|---|---|
| A Nerd Font installed on the host and selected in the terminal (MesloLGS NF recommended) | Powerlevel10k prompt icons and segment separators | Boxes, question marks, or gaps in the prompt |
| UTF-8 encoding | The image runs with `LANG=en_US.UTF-8` | Garbled symbols |
| 256 colors | The rainbow prompt palette | A flat, uncolored prompt |
| OSC 4/10/11 color escapes | Switching to the capsule colors on shell entry | The capsule shell keeps the host colors |
| OSC 1/2 title escapes | `[capsule:<name>]` window and tab titles | Titles show the host default |

The font is the only item set up by hand: the image ships no fonts.
Current terminals such as kitty, iTerm2, GNOME Terminal, and WezTerm meet the
other requirements by default.

`docker compose exec -it` starts the shell with `TERM=xterm`, which declares
only 8 colors; the shell upgrades it to `xterm-256color`. Any other `TERM`
passed with `-e TERM=...` is kept as is and needs a matching terminfo entry in
the image.

**Troubleshooting**, inside the capsule:

- Icons show as boxes: install a Nerd Font on the host and select it in the
  terminal profile, then open a new window.
- Prompt has no colors: `echo $TERM` should print `xterm-256color`.
- Colors don't switch on entry: check `CAPSULE_TERM_COLORS` is not `0`.
- Either of the last two on an older image: rebuild the base image and recreate
  the capsule; `/etc/capsule/info.json` shows which commit the image was built
  from.

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

## Git identity and repositories

A capsule declares its git identity and repos in one file, `git.yaml`, mounted
read-only at `~/.capsule-git.yaml` (see [`example/git.yaml`](../example/git.yaml)).
The format is defined by [`schema/git.schema.json`](../schema/git.schema.json)
(JSON Schema 2020-12); add the `yaml-language-server` `$schema` modeline from
the example for editor validation.

```yaml
version: 1
identity:
  name: Ada Lovelace
  email: ada@example.com
repos:
  fenix-images:
    url: https://github.com/NordHero/fenix-images.git
    branch: main
  customer-svc:
    url: https://github.com/customer/svc.git
    identity:
      email: ada@customer.example
```

| Key | Required | Meaning |
|---|---|---|
| `version` | yes | Format version; only `1` is accepted. |
| `identity.name`, `identity.email` | no | Default `user.name` / `user.email`. |
| `repos.<dir>` | no | A repo cloned into `~/workspace/<dir>`. `<dir>` matches `^[A-Za-z0-9_][A-Za-z0-9._-]{0,99}$`. |
| `repos.<dir>.url` | yes | Clone URL: `https://...`, or `git@github.com:<owner>/<repo>` (cloned only in [SSH agent mode](#ssh-agent-forwarding-hardware-keys)). |
| `repos.<dir>.branch` | no | Branch or tag to check out; defaults to the remote default branch. |
| `repos.<dir>.identity` | no | `name` / `email` override for that repo only. |

Unknown keys, duplicate keys, multiple YAML documents, and anchors/aliases are
refused. `capsule-git check` validates the file and prints each error with its
path; an invalid file is refused as a whole (no identity applied, no repos
cloned) and each shell prints a reminder until a restart applies a valid file.

**Identity.** On every start, `capsule-git apply` regenerates
`~/.config/capsule/git/config` and includes it last from the global git
config: `identity` becomes `user.name` / `user.email`, and each per-repo
`identity` becomes an `includeIf "gitdir:~/workspace/<dir>/"` block. Changes
therefore apply to existing clones after a restart, and `git.yaml` overrides a
`user.*` set by hand with `git config --global`. A repo's own `git config
--local user.*` still takes precedence. Removing the file removes the identity
on the next start.

**Repositories.** `capsule-sync` clones over HTTPS using the `gh` credential helper, is
**idempotent** (an existing target dir is skipped, never pulled or reset), and
prints a per-repo `cloned|skipped|failed` line plus a summary. Git never prompts
for credentials (`GIT_TERMINAL_PROMPT=0`); a repo needing auth fails fast. The
entrypoint attempts it on start (non-blocking): public repos clone, anything
needing auth is reported. It runs again after `capsule-unlock` unlocks the
keyring, and manually after `gh auth login`. It never blocks or fails container
start.

**Removed and deprecated.** `CAPSULE_REPOS`, `CAPSULE_REPOS_FILE`,
`GIT_USER_NAME`, and `GIT_USER_EMAIL` are ignored; when set, the entrypoint log
and each shell print a warning. The text manifest `~/.capsule-repos` (one
`url [dir] [branch]` per line) is still read by `capsule-sync` with a
deprecation warning and will be removed; its `dir` must match the same pattern
as `git.yaml`.

## SSH agent forwarding (hardware keys)

Opt-in: git can authenticate to GitHub over SSH with a key that never enters
the capsule, typically a FIDO2 hardware key (`ed25519-sk`). The host's
ssh-agent socket is mounted into the capsule, and every signature is made on
the host; with a hardware key each one needs a touch (and the PIN with
`-O verify-required`). `cap_drop: ALL` and `no-new-privileges` stay.

```yaml
services:
  dev:
    volumes:
      - /run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock
    environment:
      CAPSULE_GIT_SSH: "1"
      SSH_AUTH_SOCK: /run/host-services/ssh-auth.sock
```

The socket path on the host depends on the container runtime (Docker Desktop
and OrbStack expose `/run/host-services/ssh-auth.sock`; on a Linux host mount
`$SSH_AUTH_SOCK`). The `dev` user (UID 1000) must be able to open it; the
capsule cannot change its permissions.

With `CAPSULE_GIT_SSH=1`:

- The entrypoint leaves git's SSH transport enabled (otherwise it sets
  `protocol.ssh.allow never`) and logs whether the agent is reachable and how
  many keys it holds (`ssh-agent: N key(s) ...`).
- `SSH_AUTH_SOCK` from `compose.yaml` is kept: `~/.keyring-env` does not
  override it, and `capsule-unlock` starts gnome-keyring without its `ssh`
  component.
- `capsule-sync` clones `git@github.com:<owner>/<repo>` URLs from `git.yaml`
  (with `BatchMode=yes`, so a missing key fails instead of prompting). Without
  the flag such URLs are refused. HTTPS repos still use the `gh` credential
  helper, and `gh` itself still needs `gh auth login` for API use.

GitHub's SSH host keys are pinned in the image (`/etc/ssh/ssh_known_hosts`,
from `api.github.com/meta`, fingerprints checked against GitHub's documentation),
and `/etc/ssh/ssh_config.d/10-capsule-github.conf` makes `github.com` use only
that file (`StrictHostKeyChecking yes`, `UserKnownHostsFile /dev/null`). A
changed host key fails the connection instead of being trusted on first use.

Check inside the capsule: `ssh-add -l` lists the forwarded keys and
`ssh -T git@github.com` greets the account the key belongs to.

## Health

A `HEALTHCHECK` reads `~/.provisioned/status`: the container is **healthy** when
there is no `mise.toml` to provision (status file absent) or provisioning
finished cleanly (`rc=0`), and **unhealthy** when provisioning finished with a
failure. Because provisioning is non-fatal, a degraded container stays up and
is visible as `unhealthy` in `docker ps` rather than crash-looping.

## Provisioning

`provision.sh` is the single, re-runnable provisioning entry point. The
entrypoint calls it on start; it runs `mise install` then `extra-tools.sh`.

**Trust.** A `mise.toml` runs code (`[env]`, hooks), and `mise install` trusts
the config it reads. `provision.sh` therefore installs nothing until
`~/mise.toml` is trusted: set `CAPSULE_TRUST_MISE=1` in `compose.yaml` to trust
it on start (the example does), or review it and run
`mise trust ~/mise.toml && provision.sh` once. Until then it reports
`mise: untrusted`, the container stays healthy, and each shell prints a
reminder. Trust is by path and persists in the home volume.

Provisioning is **non-fatal**: a tool that fails to install no longer stops the
container from starting — the environment always comes up, and the failure is
reported instead of hidden. Re-run it any time with `provision.sh`.

- **Status markers** (greppable in the logs): `mise: ok|failed|untrusted`, one
  `extra-tool: <name>[@<ver>]: ok|failed|unknown` line per tool, a summary
  `extra-tools: summary ok=N failed=M (failed: ...)`, and
  `provision: summary mise=... extra-tools=...`.
- **Report**: full output and a one-line status are written to
  `~/.provisioned/last-run.log` and `~/.provisioned/status`.
- **Strict mode**: set `EXTRA_TOOLS_STRICT=1` to make `extra-tools.sh` exit
  non-zero when any tool fails (default is non-fatal).

## Prompt, window title, and terminal colors

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

The shell also sets the Dracula palette with standard OSC 4/10/11/12/17/19
escapes and resets it (OSC 104/110/111/112/117/119) on exit, so kitty, GNOME
Terminal, and other xterm-compatible terminals switch colors without profiles.
In iTerm2 this matches the default `fenix-devcontainer` profile. Set
`CAPSULE_TERM_COLORS=0` to opt out (defaults to the
`CAPSULE_ITERM_PROFILE_SWITCH` value), e.g. when `ITERM_DEVCONTAINER_PROFILE`
points to a profile with different colors. If the shell is killed rather than
exited, the colors stay until the terminal resets them.

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
  A fresh volume then needs only
  `aws sso login`; no `aws configure sso`. The logic is generic and a no-op when
  the vars are unset or a config already exists; only non-secret identifiers
  come from the capsule.
- **Mounted file.** Mount a prewritten `~/.aws/config` read-only at
  `/home/dev/.aws/config`. Because the env seeding is guarded by
  `[ ! -f ~/.aws/config ]`, a mounted config takes precedence and the env path
  is a no-op. This is the natural source of truth when you need multiple
  profiles or sso-sessions; keep it non-secret (identifiers only).

## Environment variables

Every variable the image and its scripts read. **When** says when a value takes
effect: **start** = container start (entrypoint), **shell** = each interactive
shell, **command** = when that command runs. Values set under `environment:` in
`compose.yaml` apply after `docker compose up -d` recreates the container.

### Capsule settings (`compose.yaml`)

**Identity and shell**

| Variable | Default | When | Effect |
|---|---|---|---|
| `CAPSULE_NAME` | container hostname | shell | Label in the window title (`[capsule:<name>] <dir>`) and the login banner. |
| `CAPSULE_WELCOME` | unset | shell | One-line login banner. Ignored when `~/.capsule-welcome` exists. Control characters except tab and newline are stripped. |
| `CAPSULE_KEYRING_PROMPT` | `1` | shell | `0` skips running `capsule-unlock` at shell start. |
| `CAPSULE_TERM_COLORS` | value of `CAPSULE_ITERM_PROFILE_SWITCH` | shell | `0` disables the portable Dracula color switch (OSC 4/10/11/...). |
| `CAPSULE_ITERM_PROFILE_SWITCH` | `1` | shell | `0` disables the iTerm2 profile switch; also disables the color switch unless `CAPSULE_TERM_COLORS` is set. |
| `ITERM_DEVCONTAINER_PROFILE` | `fenix-devcontainer` | shell | iTerm2 profile selected on shell start. |
| `ITERM_DEFAULT_PROFILE` | `fenix` | shell | iTerm2 profile restored on shell exit. |

**Provisioning**

| Variable | Default | When | Effect |
|---|---|---|---|
| `CAPSULE_TRUST_MISE` | unset | start | `1` trusts `~/mise.toml` before provisioning. Any other value leaves trust to a manual `mise trust`. |
| `EXTRA_TOOLS_STRICT` | `0` | start, command | `1` makes `extra-tools.sh` exit non-zero when a tool fails. `provision.sh` reports failed tools either way. |
| `EXTRA_TOOLS` | unset | start, command | Space-separated `tool[@version]` list. Set it in `mise.toml` under `[env]`, not in `compose.yaml`: `provision.sh` reads it from the file and ignores the container value. See [`TOOLS.md`](TOOLS.md). |

mise's own `MISE_*` variables pass through to mise unchanged.

**Git identity and repositories** (see [Git identity and repositories](#git-identity-and-repositories))

| Variable | Default | When | Effect |
|---|---|---|---|
| `CAPSULE_GIT_FILE` | `~/.capsule-git.yaml` | start, unlock, command | Path of `git.yaml` read by `capsule-git` and `capsule-sync`. Automatic `capsule-sync` runs at start and after unlock trigger when this file or the legacy `~/.capsule-repos` exists. |
| `CAPSULE_WORKSPACE` | `~/workspace` | start, command | Directory `capsule-sync` clones into and per-repo identities match against. |

**SSH agent forwarding** (see [SSH agent forwarding](#ssh-agent-forwarding-hardware-keys))

| Variable | Default | When | Effect |
|---|---|---|---|
| `CAPSULE_GIT_SSH` | unset | start, unlock, command | `1` enables git over SSH with the forwarded agent: keeps `SSH_AUTH_SOCK`, runs gnome-keyring without its `ssh` component, and lets `capsule-sync` clone `git@github.com:` URLs. |
| `SSH_AUTH_SOCK` | unset | start, shell | Path of the mounted host agent socket. Used only with `CAPSULE_GIT_SSH=1`; otherwise `~/.keyring-env` sets it to gnome-keyring's agent. |

**Keyring** (see [Credentials and the keyring](#credentials-and-the-keyring))

| Variable | Default | When | Effect |
|---|---|---|---|
| `KEYRING_PASSWORD_FILE` | `/run/secrets/keyring_password` | start | If the file exists, the keyring is unlocked with its content. |

**AWS config seeding** (see [Credentials and the keyring](#credentials-and-the-keyring)).
Applied at start only when both required variables are set and
`~/.aws/config` does not exist.

| Variable | Default | Effect |
|---|---|---|
| `AWS_SSO_START_URL` | required | `sso_start_url` of the `[sso-session]` block. |
| `AWS_SSO_REGION` | required | `sso_region`; last fallback for the profile `region`. |
| `AWS_SSO_SESSION` | `sso` | Name of the `[sso-session]` block. |
| `AWS_SSO_ACCOUNT_ID` | unset | `sso_account_id` of the profile; omitted when unset. |
| `AWS_SSO_ROLE_NAME` | unset | `sso_role_name` of the profile; omitted when unset. |
| `AWS_PROFILE` | `default` | Profile written: `[default]`, otherwise `[profile <name>]`. |
| `AWS_REGION` | `AWS_DEFAULT_REGION`, then `AWS_SSO_REGION` | Profile `region`. |
| `AWS_DEFAULT_OUTPUT` | `json` | Profile `output`. |

The AWS CLI itself also reads `AWS_PROFILE`, `AWS_REGION`, and
`AWS_DEFAULT_OUTPUT` at runtime.

### Set by the image

Not meant to be overridden.

| Variable | Value | Purpose |
|---|---|---|
| `CAPSULE_INFO` | `fenix-base <version> (<commit>, built <date>)` | Login banner line and `capsule-info` output (see [Provenance](#provenance)). |
| `BROWSER` | `true` | Login flows (`gh auth login`, `aws sso login`) do not fail trying to open a browser; open the printed URL on the host. |
| `LANG`, `LC_ALL` | `en_US.UTF-8` | UTF-8 locale. |
| `TERM` | `xterm` upgraded to `xterm-256color` | See [Host terminal requirements](#host-terminal-requirements). |
| `PATH` | mise shims, `~/.local/bin`, `/usr/local/bin` first | Tools installed by mise and `extra-tools.sh` resolve first. |
| `DEV_USER`, `DEV_UID`, `DEV_GID`, `DEV_HOME` | `dev`, `1000`, `1000`, `/home/dev` | Build-time user layout; changing them at runtime has no effect. |
| `DEBIAN_FRONTEND` | `noninteractive` | Non-interactive apt during the build. |

The entrypoint writes `DBUS_SESSION_BUS_ADDRESS`, `GNOME_KEYRING_CONTROL`, and
`SSH_AUTH_SOCK` (not with `CAPSULE_GIT_SSH=1`) to `~/.keyring-env`, which shells
and the `gh` wrapper source.

### Build

`build-images.sh` reads:

| Variable | Default | Effect |
|---|---|---|
| `REGISTRY` | `fenix` | Image name prefix: `<REGISTRY>-base:<TAG>`. |
| `TAG` | `local` | Image tag. |
| `IMAGE_VERSION` | `dev` | Build arg; see [Provenance](#provenance). |
| `SOURCE_COMMIT` | short `git` HEAD, else `unknown` | Build arg; see [Provenance](#provenance). |
| `BUILD_DATE` | current UTC time | Build arg; see [Provenance](#provenance). |

Pins in the `Dockerfile` are build args with defaults kept in the `Dockerfile`:
`MISE_VERSION`, `YQ_VERSION` + `YQ_SHA256_AMD64`/`YQ_SHA256_ARM64`,
`OHMYZSH_COMMIT`, `POWERLEVEL10K_COMMIT`, and `GH_APT_FINGERPRINTS`. `build-images.sh` does not forward them; override with
`docker build --build-arg NAME=value` (see [Version pinning](#version-pinning)).

## Version pinning

- **Base image** pins the `ubuntu:24.04` digest, mise (version + checksum), yq
  (version + per-architecture SHA-256),
  oh-my-zsh and powerlevel10k (commit SHAs), and the `gh` apt key
  fingerprints. Ubuntu packages and `gh` come from signed apt repos at build
  time. Rebuild with `./build-images.sh` to pick up changes.
- **`mise.toml`** pins each tool version; `mise.lock` and `.mise/locks/`
  (mounted beside it)
  pins checksums where the backend provides them (see [`TOOLS.md`](TOOLS.md)).

Upgrade deliberately by rebuilding the base image and/or bumping versions.
