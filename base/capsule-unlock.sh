#!/usr/bin/env bash
set -uo pipefail

ENV_FILE="$HOME/.keyring-env"
KEYRING_DIR="$HOME/.local/share/keyrings"
KEYRING="$KEYRING_DIR/login.keyring"
LEGACY_PASSWORD=$'\n'

[ -f "$HOME/.keyring-env" ] && . "$HOME/.keyring-env"

say() { printf 'keyring: %s\n' "$*" >&2; }

bus() { dbus-send --session --print-reply "$@" 2>/dev/null; }

has_owner() {
  bus --dest=org.freedesktop.DBus / org.freedesktop.DBus.NameHasOwner string:org.freedesktop.secrets \
    | grep -q 'boolean true'
}

locked_state() {
  bus --dest=org.freedesktop.secrets /org/freedesktop/secrets/collection/login \
    org.freedesktop.DBus.Properties.Get string:org.freedesktop.Secret.Collection string:Locked \
    | awk '/boolean/{print $3}'
}

is_unlocked() { [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ "$(locked_state)" = "false" ]; }

ssh_forwarded() { [ "${CAPSULE_GIT_SSH:-}" = "1" ]; }

write_env() {
  {
    printf "export DBUS_SESSION_BUS_ADDRESS='%s'\n" "${DBUS_SESSION_BUS_ADDRESS:-}"
    printf "export GNOME_KEYRING_CONTROL='%s'\n" "${GNOME_KEYRING_CONTROL:-}"
    ssh_forwarded || printf "export SSH_AUTH_SOCK='%s'\n" "${SSH_AUTH_SOCK:-}"
  } >"$ENV_FILE"
}

stop_daemon() {
  local pid
  pid="$(bus --dest=org.freedesktop.DBus / org.freedesktop.DBus.GetConnectionUnixProcessID string:org.freedesktop.secrets \
    | awk '/uint32/{print $2}')"
  [ -n "$pid" ] && kill "$pid" 2>/dev/null
  for _ in $(seq 1 50); do
    has_owner || break
    sleep 0.1
  done
  GNOME_KEYRING_CONTROL=""
  ssh_forwarded || SSH_AUTH_SOCK=""
  write_env
}

start_daemon() {
  local out line value state
  local components=secrets,pkcs11,ssh
  ssh_forwarded && components=secrets,pkcs11
  out="$(printf '%s' "$1" | gnome-keyring-daemon --unlock --components="$components" 2>/dev/null)"
  while IFS='=' read -r line value; do
    case "$line" in
      GNOME_KEYRING_CONTROL) export GNOME_KEYRING_CONTROL="$value" ;;
      SSH_AUTH_SOCK) ssh_forwarded || export SSH_AUTH_SOCK="$value" ;;
    esac
  done <<<"$out"
  write_env
  for _ in $(seq 1 50); do
    state="$(locked_state)"
    [ -n "$state" ] && break
    sleep 0.1
  done
  [ "$state" = "false" ]
}

try_password() {
  has_owner && stop_daemon
  start_daemon "$1" && return 0
  stop_daemon
  return 1
}

read_password() {
  local prompt="$1" pw
  printf '%s' "$prompt" >&2
  if [ -t 0 ]; then
    IFS= read -rs pw
    printf '\n' >&2
  else
    IFS= read -r pw
  fi
  printf '%s' "$pw"
}

new_password() {
  local pw confirm
  for _ in 1 2 3; do
    pw="$(read_password 'New keyring password: ')"
    if [ -z "$pw" ]; then
      say "empty password refused"
      continue
    fi
    confirm="$(read_password 'Confirm keyring password: ')"
    if [ "$pw" != "$confirm" ]; then
      say "passwords do not match"
      continue
    fi
    if try_password "$pw" && [ -f "$KEYRING" ]; then
      say "created and unlocked"
      return 0
    fi
    say "could not create keyring"
    return 1
  done
  return 1
}

existing_password() {
  local pw
  for _ in 1 2 3; do
    pw="$(read_password 'Keyring password: ')"
    [ -z "$pw" ] && continue
    if try_password "$pw"; then
      say "unlocked"
      return 0
    fi
    say "wrong password"
  done
  return 1
}

reset_keyring() {
  has_owner && stop_daemon
  rm -f "$KEYRING" "$KEYRING_DIR/user.keystore"
}

after_unlock() {
  if grep -qs 'oauth_token' "$HOME/.config/gh/hosts.yml"; then
    say "plaintext gh token in ~/.config/gh/hosts.yml; run 'gh auth logout' then 'gh auth login' to move it into the keyring"
  fi
  if [ -x /usr/local/bin/capsule-sync ] && { [ -f "${CAPSULE_GIT_FILE:-$HOME/.capsule-git.yaml}" ] || [ -f "$HOME/.capsule-repos" ]; }; then
    /usr/local/bin/capsule-sync || true
  fi
}

from_file() {
  local pw
  if [ ! -r "$1" ]; then
    say "password file not readable: $1"
    return 1
  fi
  pw="$(cat -- "$1")"
  if [ -z "$pw" ]; then
    say "password file is empty; keyring stays locked"
    return 1
  fi
  if [ -f "$KEYRING" ] && try_password "$LEGACY_PASSWORD"; then
    stop_daemon
    say "keyring has no password set; run 'capsule-unlock' in a shell to reset it"
    return 1
  fi
  if try_password "$pw"; then
    say "unlocked from $1"
    return 0
  fi
  say "password from $1 did not unlock the keyring"
  return 1
}

interactive() {
  local answer
  if is_unlocked; then
    say "unlocked"
    return 0
  fi
  if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    say "no D-Bus session (see ~/.keyring-env)"
    return 1
  fi
  mkdir -p "$KEYRING_DIR" "$HOME/.cache"
  exec 9>"$HOME/.cache/capsule-unlock.lock"
  if ! flock -n 9; then
    say "unlock already in progress in another shell"
    return 1
  fi
  if [ -f "$KEYRING" ] && try_password "$LEGACY_PASSWORD"; then
    say "this keyring was created without a password; stored tokens are readable from any copy of the volume"
    printf 'Reset the keyring and set a password? Stored tokens are deleted; sign in again afterwards. [y/N] ' >&2
    IFS= read -r answer
    case "$answer" in
      y | Y | yes | YES)
        reset_keyring
        ;;
      *)
        say "kept without a password; run 'capsule-unlock' to reset later"
        return 0
        ;;
    esac
  fi
  if [ -f "$KEYRING" ]; then
    existing_password || {
      say "keyring stays locked; run 'capsule-unlock' to retry"
      return 1
    }
  else
    printf 'Set a password for the keyring that stores tokens such as gh.\n' >&2
    new_password || {
      say "keyring stays locked; run 'capsule-unlock' to retry"
      return 1
    }
  fi
  after_unlock
  return 0
}

case "${1:-}" in
  --status)
    if is_unlocked; then
      echo "unlocked"
      exit 0
    fi
    echo "locked"
    exit 1
    ;;
  --password-file)
    from_file "${2:-}"
    exit $?
    ;;
  "")
    interactive
    exit $?
    ;;
  *)
    echo "usage: capsule-unlock [--status | --password-file FILE]" >&2
    exit 2
    ;;
esac
