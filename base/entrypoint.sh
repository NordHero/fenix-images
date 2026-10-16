#!/bin/bash
set -u

mkdir -p "$HOME/.cache" "$HOME/.local/share/keyrings" "$HOME/workspace" || true
rm -rf "$HOME"/.cache/keyring-* "$HOME/.cache/capsule-unlock.lock" || true

eval "$(dbus-launch --sh-syntax)" 2>/dev/null || true

{
  printf "export DBUS_SESSION_BUS_ADDRESS='%s'\n" "${DBUS_SESSION_BUS_ADDRESS:-}"
  printf "export GNOME_KEYRING_CONTROL=''\n"
  [ "${CAPSULE_GIT_SSH:-}" = "1" ] || printf "export SSH_AUTH_SOCK=''\n"
} >"$HOME/.keyring-env" || true

KEYRING_PASSWORD_FILE="${KEYRING_PASSWORD_FILE:-/run/secrets/keyring_password}"
if [ -f "$KEYRING_PASSWORD_FILE" ]; then
  /usr/local/bin/capsule-unlock --password-file "$KEYRING_PASSWORD_FILE" || true
fi

git config --global --unset-all safe.directory '^\*$' || true
if [ "${CAPSULE_GIT_SSH:-}" = "1" ]; then
  git config --global --unset-all protocol.ssh.allow || true
  ssh-add -l >/dev/null 2>&1
  case $? in
    0) echo "ssh-agent: $(ssh-add -l 2>/dev/null | wc -l) key(s) via SSH_AUTH_SOCK=${SSH_AUTH_SOCK:-}" >&2 ;;
    1) echo "ssh-agent: reachable via SSH_AUTH_SOCK=${SSH_AUTH_SOCK:-} but holds no keys; run ssh-add on the host" >&2 ;;
    *) echo "ssh-agent: not reachable (SSH_AUTH_SOCK=${SSH_AUTH_SOCK:-}); mount the host agent socket and set SSH_AUTH_SOCK" >&2 ;;
  esac
else
  git config --global protocol.ssh.allow never || true
fi
git config --global --unset-all credential.https://github.com.helper || true
git config --global --add credential.https://github.com.helper '' || true
git config --global --add credential.https://github.com.helper '!gh auth git-credential' || true

if [ -d /opt/devbox-skel ]; then
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    cp -a /opt/devbox-skel/.oh-my-zsh "$HOME/.oh-my-zsh" || true
  fi
  mkdir -p "$HOME/.oh-my-zsh/custom/themes" || true
  rm -rf "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" || true
  cp -a /opt/devbox-skel/.oh-my-zsh-custom/themes/powerlevel10k \
    "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" || true
  cp -f /opt/devbox-skel/.zshrc "$HOME/.zshrc" || true
  cp -f /opt/devbox-skel/.p10k.zsh "$HOME/.p10k.zsh" || true
fi

/usr/local/bin/capsule-git apply || true

if [ -n "${AWS_SSO_START_URL:-}" ] && [ -n "${AWS_SSO_REGION:-}" ] && [ ! -f "$HOME/.aws/config" ]; then
  sso_session="${AWS_SSO_SESSION:-sso}"
  profile="${AWS_PROFILE:-default}"
  region="${AWS_REGION:-${AWS_DEFAULT_REGION:-$AWS_SSO_REGION}}"
  mkdir -p "$HOME/.aws" || true
  {
    printf '[sso-session %s]\n' "$sso_session"
    printf 'sso_start_url = %s\n' "$AWS_SSO_START_URL"
    printf 'sso_region = %s\n' "$AWS_SSO_REGION"
    printf 'sso_registration_scopes = sso:account:access\n'
    printf '\n'
    if [ "$profile" = "default" ]; then
      printf '[default]\n'
    else
      printf '[profile %s]\n' "$profile"
    fi
    printf 'sso_session = %s\n' "$sso_session"
    [ -n "${AWS_SSO_ACCOUNT_ID:-}" ] && printf 'sso_account_id = %s\n' "$AWS_SSO_ACCOUNT_ID"
    [ -n "${AWS_SSO_ROLE_NAME:-}" ] && printf 'sso_role_name = %s\n' "$AWS_SSO_ROLE_NAME"
    printf 'region = %s\n' "$region"
    printf 'output = %s\n' "${AWS_DEFAULT_OUTPUT:-json}"
  } >"$HOME/.aws/config" 2>/dev/null || true
fi

if [ -f "$HOME/mise.toml" ] && [ -x /usr/local/bin/provision.sh ]; then
  /usr/local/bin/provision.sh || echo "provision: incomplete; run 'provision.sh' to retry (see ~/.provisioned/last-run.log)" >&2
fi

if [ -x /usr/local/bin/capsule-sync ] && { [ -f "${CAPSULE_GIT_FILE:-$HOME/.capsule-git.yaml}" ] || [ -f "$HOME/.capsule-repos" ]; }; then
  /usr/local/bin/capsule-sync || echo "capsule-sync: some repos pending — run 'capsule-sync' after 'gh auth login'" >&2
fi

exec sleep infinity
