#!/usr/bin/env bash
set -euo pipefail

if [ -n "${CAPSULE_INFO:-}" ]; then
  printf '%s\n' "$CAPSULE_INFO"
fi

if [ -f /etc/capsule/info.json ]; then
  cat /etc/capsule/info.json
fi
