#!/usr/bin/env bash

export TOOL_NAME="gemini"
export TOOL_LAYER="agents"
export TOOL_ANCHOR="npm-integrity+node-gpg"
export TOOL_ANCHOR_STRENGTH="integrity+gpg"
export TOOL_SIZE="~430MB"
export TOOL_UPDATE="self-update"
export TOOL_MISE_ALIASES="gemini gemini-cli npm:@google/gemini-cli node nodejs"
export TOOL_COMMANDS="gemini"

NODE_VERSION="v24.22.0"
NODE_SHA256_AMD64="cc2f601cee82d9a5a233302fe307abc600727035fd7d2c3a3571755989e95008"
NODE_SHA256_ARM64="fef00bb4d36e1c50104a9775a10359beee98f162b4104dd12472c75065c6a143"
NODE_RELEASE_KEYS="https://raw.githubusercontent.com/nodejs/release-keys/main/gpg/pubring.kbx"
GEMINI_PREFIX="/opt/gemini"
GEMINI_NODE="${GEMINI_PREFIX}/node"

tool_install() {
  set -euo pipefail

  case "$(dpkg --print-architecture)" in
    amd64)
      slug="x64"
      want="$NODE_SHA256_AMD64"
      ;;
    arm64)
      slug="arm64"
      want="$NODE_SHA256_ARM64"
      ;;
    *)
      echo "gemini: unsupported architecture" >&2
      exit 1
      ;;
  esac

  apt-get update
  apt-get install -y --no-install-recommends xz-utils
  rm -rf /var/lib/apt/lists/*

  work="$(mktemp -d)"
  export GNUPGHOME="$work/gnupg"
  mkdir -p "$GNUPGHOME"
  chmod 700 "$GNUPGHOME"

  tarball="node-${NODE_VERSION}-linux-${slug}.tar.xz"
  base="https://nodejs.org/dist/${NODE_VERSION}"
  curl -fsSL "${base}/${tarball}" -o "$work/node.tar.xz"
  curl -fsSL "${base}/SHASUMS256.txt.asc" -o "$work/SHASUMS256.txt.asc"
  curl -fsSL "$NODE_RELEASE_KEYS" -o "$GNUPGHOME/pubring.kbx"

  gpg --output "$work/SHASUMS256.txt" --decrypt "$work/SHASUMS256.txt.asc"
  grep " ${tarball}\$" "$work/SHASUMS256.txt" | grep -q "^${want} "
  echo "${want}  $work/node.tar.xz" | sha256sum -c -

  mkdir -p "$GEMINI_NODE"
  tar -xJf "$work/node.tar.xz" -C "$GEMINI_NODE" --strip-components=1

  cp /usr/local/share/capsule-tools/gemini/package.json "$GEMINI_PREFIX/package.json"
  cp /usr/local/share/capsule-tools/gemini/package-lock.json "$GEMINI_PREFIX/package-lock.json"

  (
    cd "$GEMINI_PREFIX"
    PATH="${GEMINI_NODE}/bin:$PATH" npm ci --omit=dev --no-audit --no-fund
  )

  cat >/usr/local/bin/gemini <<EOF
#!/bin/sh
exec "${GEMINI_NODE}/bin/node" "${GEMINI_PREFIX}/node_modules/.bin/gemini" "\$@"
EOF
  chmod 0755 /usr/local/bin/gemini

  chown -R "${DEV_UID:-1000}:${DEV_GID:-1000}" "$GEMINI_PREFIX"
  rm -rf "$work"

  /usr/local/bin/gemini --version
}
