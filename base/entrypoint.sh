#!/bin/bash
set -u

mkdir -p "$HOME/.cache" "$HOME/.local/share/keyrings" "$HOME/workspace" || true

eval "$(dbus-launch --sh-syntax)" 2>/dev/null || true
eval "$(printf '\n' | gnome-keyring-daemon --unlock --components=secrets,pkcs11,ssh 2>/dev/null)" || true

cat >"$HOME/.keyring-env" <<EOF || true
export DBUS_SESSION_BUS_ADDRESS='${DBUS_SESSION_BUS_ADDRESS:-}'
export GNOME_KEYRING_CONTROL='${GNOME_KEYRING_CONTROL:-}'
export SSH_AUTH_SOCK='${SSH_AUTH_SOCK:-}'
EOF

git config --global --add safe.directory "*" || true
git config --global protocol.ssh.allow never || true
git config --global credential.https://github.com.helper '' || true
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

if [ -n "${GIT_USER_NAME:-}" ]; then git config --global user.name "$GIT_USER_NAME" || true; fi
if [ -n "${GIT_USER_EMAIL:-}" ]; then git config --global user.email "$GIT_USER_EMAIL" || true; fi

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

if [ -x /usr/local/bin/kapsuli-sync ] && { [ -n "${KAPSULI_REPOS:-}" ] || [ -f "$HOME/.kapsuli-repos" ]; }; then
  /usr/local/bin/kapsuli-sync || echo "kapsuli-sync: some repos pending — run 'kapsuli-sync' after 'gh auth login'" >&2
fi

exec sleep infinity
