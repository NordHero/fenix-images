#!/usr/bin/env bash

export TOOL_NAME="az"
export TOOL_LAYER="cloud-ops"
export TOOL_ANCHOR="apt(BC52..29CF)"
export TOOL_ANCHOR_STRENGTH="vendor-apt"
export TOOL_SIZE="~620MB"
export TOOL_UPDATE="apt+rebuild"

AZ_APT_FINGERPRINT="BC528686B50D79E339D3721CEB3E94ADBE1229CF"
AZ_KEY_URL="https://packages.microsoft.com/keys/microsoft.asc"
AZ_KEYRING="/usr/share/keyrings/microsoft.gpg"
AZ_DIST="noble"

tool_install() {
  set -euo pipefail

  curl -fsSL "$AZ_KEY_URL" | gpg --dearmor -o "$AZ_KEYRING"
  got="$(gpg --show-keys --with-colons --with-fingerprint "$AZ_KEYRING" | awk -F: '/^fpr:/{print $10; exit}')"
  test "$got" = "$AZ_APT_FINGERPRINT"

  echo "deb [arch=$(dpkg --print-architecture) signed-by=${AZ_KEYRING}] https://packages.microsoft.com/repos/azure-cli ${AZ_DIST} main" \
    >/etc/apt/sources.list.d/azure-cli.list

  apt-get update
  apt-get install -y --no-install-recommends azure-cli
  rm -rf /var/lib/apt/lists/*

  az version
}
