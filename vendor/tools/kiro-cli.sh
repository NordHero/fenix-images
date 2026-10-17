#!/usr/bin/env bash

export TOOL_NAME="kiro-cli"
export TOOL_LAYER="agents"
export TOOL_ANCHOR="checksum-only"
export TOOL_ANCHOR_STRENGTH="checksum-pinned"
export TOOL_SIZE="~155MB"
export TOOL_UPDATE="self-update"

KIRO_CLI_VERSION="2.32.0"
KIRO_CLI_SHA256_AMD64="05989f9bfe465b304e8d1b2dba50aec2b84fcc1deaa4c0773af3f539d6e0d312"
KIRO_CLI_SHA256_ARM64="98e5b923c7ed8bf589eb9b9d823e6611cba96f26c719cdb053959897738623ec"
KIRO_CLI_BASE="https://prod.download.cli.kiro.dev/stable"
KIRO_CLI_SEED="/opt/capsule/agents/kiro-cli"

tool_install() {
  set -euo pipefail

  case "$(dpkg --print-architecture)" in
    amd64)
      slug="x86_64"
      want="$KIRO_CLI_SHA256_AMD64"
      ;;
    arm64)
      slug="aarch64"
      want="$KIRO_CLI_SHA256_ARM64"
      ;;
    *)
      echo "kiro-cli: unsupported architecture" >&2
      exit 1
      ;;
  esac

  asset="kirocli-${slug}-linux.tar.gz"
  work="$(mktemp -d)"
  curl -fsSL "${KIRO_CLI_BASE}/${KIRO_CLI_VERSION}/${asset}" -o "$work/kirocli.tar.gz"
  echo "${want}  $work/kirocli.tar.gz" | sha256sum -c -

  tar -xzf "$work/kirocli.tar.gz" -C "$work"
  rm -rf "$KIRO_CLI_SEED"
  mkdir -p "$KIRO_CLI_SEED"
  cp -a "$work/kirocli/bin/." "$KIRO_CLI_SEED/"
  for b in kiro-cli kiro-cli-chat kiro-cli-term q qchat; do
    [ -e "$KIRO_CLI_SEED/$b" ] && ln -sf "$KIRO_CLI_SEED/$b" "/usr/local/bin/$b"
  done
  chown -R "${DEV_UID:-1000}:${DEV_GID:-1000}" "$KIRO_CLI_SEED"

  rm -rf "$work"

  /usr/local/bin/kiro-cli --version
}
