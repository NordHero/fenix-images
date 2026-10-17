#!/usr/bin/env bash

export TOOL_NAME="gcloud"
export TOOL_LAYER="cloud-ops"
export TOOL_ANCHOR="apt(35BA..15A3)"
export TOOL_ANCHOR_STRENGTH="vendor-apt"
export TOOL_SIZE="~330MB"
export TOOL_UPDATE="apt+rebuild"

GCLOUD_APT_FINGERPRINT="35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3"
GCLOUD_KEY_URL="https://packages.cloud.google.com/apt/doc/apt-key.gpg"
GCLOUD_KEYRING="/usr/share/keyrings/cloud.google.gpg"

tool_install() {
  set -euo pipefail

  curl -fsSL "$GCLOUD_KEY_URL" | gpg --dearmor -o "$GCLOUD_KEYRING"
  got="$(gpg --show-keys --with-colons --with-fingerprint "$GCLOUD_KEYRING" | awk -F: '/^fpr:/{print $10; exit}')"
  test "$got" = "$GCLOUD_APT_FINGERPRINT"

  echo "deb [signed-by=${GCLOUD_KEYRING}] https://packages.cloud.google.com/apt cloud-sdk main" \
    >/etc/apt/sources.list.d/google-cloud-sdk.list

  mkdir -p /etc/dpkg/dpkg.cfg.d
  printf 'path-exclude=/usr/lib/google-cloud-sdk/platform/bundledpythonunix/*\n' \
    >/etc/dpkg/dpkg.cfg.d/exclude-gcloud-bundled-python

  apt-get update
  CLOUDSDK_SKIP_PY_COMPILATION=1 apt-get install -y --no-install-recommends google-cloud-cli
  rm -rf /var/lib/apt/lists/*

  printf 'export CLOUDSDK_PYTHON=/usr/bin/python3\n' \
    >/etc/capsule/zshrc.d/20-gcloud.zsh
  printf 'export CLOUDSDK_PYTHON=/usr/bin/python3\n' \
    >/etc/profile.d/20-gcloud.sh

  CLOUDSDK_PYTHON=/usr/bin/python3 gcloud --version
}
