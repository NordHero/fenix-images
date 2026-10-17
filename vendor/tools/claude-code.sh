#!/usr/bin/env bash

export TOOL_NAME="claude-code"
export TOOL_LAYER="agents"
export TOOL_ANCHOR="checksum-only"
export TOOL_ANCHOR_STRENGTH="checksum-tls"
export TOOL_SIZE="~285MB"
export TOOL_UPDATE="self-update"

CLAUDE_CODE_VERSION="2.1.292"
CLAUDE_CODE_SHA256_AMD64="a967e7b1d8b4e47ee421d5433027880347952b0c0857abf880e2c942a4ec93b3"
CLAUDE_CODE_SHA256_ARM64="24caa9e6ff13bf227049a2626f1c816fc895023050f0ec3b12dbf14d897367e0"
CLAUDE_CODE_BASE="https://downloads.claude.ai/claude-code-releases"
CLAUDE_CODE_SEED="/opt/capsule/agents/claude-code"

tool_install() {
  set -euo pipefail

  case "$(dpkg --print-architecture)" in
    amd64)
      platform="linux-x64"
      want="$CLAUDE_CODE_SHA256_AMD64"
      ;;
    arm64)
      platform="linux-arm64"
      want="$CLAUDE_CODE_SHA256_ARM64"
      ;;
    *)
      echo "claude-code: unsupported architecture" >&2
      exit 1
      ;;
  esac

  base="${CLAUDE_CODE_BASE}/${CLAUDE_CODE_VERSION}"
  work="$(mktemp -d)"

  curl -fsSL "${base}/manifest.json" -o "$work/manifest.json"
  manifest_version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$work/manifest.json")"
  test "$manifest_version" = "$CLAUDE_CODE_VERSION"
  manifest_checksum="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["platforms"][sys.argv[2]]["checksum"])' "$work/manifest.json" "$platform")"
  test "$manifest_checksum" = "$want"

  curl -fsSL "${base}/${platform}/claude" -o "$work/claude"
  echo "${want}  $work/claude" | sha256sum -c -

  mkdir -p "$CLAUDE_CODE_SEED"
  install -m 0755 "$work/claude" "$CLAUDE_CODE_SEED/claude"
  ln -sf "$CLAUDE_CODE_SEED/claude" /usr/local/bin/claude
  chown -R "${DEV_UID:-1000}:${DEV_GID:-1000}" "$CLAUDE_CODE_SEED"

  rm -rf "$work"

  /usr/local/bin/claude --version
}
