#!/usr/bin/env bash
set -euo pipefail

if [ -n "${KAPSULI_INFO:-}" ]; then
  printf '%s\n' "$KAPSULI_INFO"
fi

if [ -f /etc/kapsuli/info.json ]; then
  cat /etc/kapsuli/info.json
fi
