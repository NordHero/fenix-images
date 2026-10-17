#!/usr/bin/env bash

export TOOL_NAME="copilot"
export TOOL_LAYER="agents"
export TOOL_ANCHOR="checksum-only"
export TOOL_ANCHOR_STRENGTH="checksum-pinned"
export TOOL_SIZE="~186MB"
export TOOL_UPDATE="self-update"

COPILOT_VERSION="1.0.98"
COPILOT_SHA256_AMD64="87ddb4b3f98462b7cb13c0a6857c68ee410ec9673e2e5f64ee5bedad45825b05"
COPILOT_SHA256_ARM64="a7509dcac0e5f22886788ba4c1e2f8b9b07367e84714e42b9e7cee4d8f9fa5f2"
COPILOT_BASE="https://github.com/github/copilot-cli/releases/download"
COPILOT_SEED="/opt/capsule/agents/copilot"

tool_install() {
  set -euo pipefail

  case "$(dpkg --print-architecture)" in
    amd64)
      asset="copilot-linux-x64.tar.gz"
      want="$COPILOT_SHA256_AMD64"
      ;;
    arm64)
      asset="copilot-linux-arm64.tar.gz"
      want="$COPILOT_SHA256_ARM64"
      ;;
    *)
      echo "copilot: unsupported architecture" >&2
      exit 1
      ;;
  esac

  work="$(mktemp -d)"
  curl -fsSL "${COPILOT_BASE}/v${COPILOT_VERSION}/${asset}" -o "$work/copilot.tar.gz"
  echo "${want}  $work/copilot.tar.gz" | sha256sum -c -

  tar -xzf "$work/copilot.tar.gz" -C "$work"
  mkdir -p "$COPILOT_SEED"
  install -m 0755 "$work/copilot" "$COPILOT_SEED/copilot"
  ln -sf "$COPILOT_SEED/copilot" /usr/local/bin/copilot
  chown -R "${DEV_UID:-1000}:${DEV_GID:-1000}" "$COPILOT_SEED"

  rm -rf "$work"

  /usr/local/bin/copilot --version
}
