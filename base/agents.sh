#!/usr/bin/env bash
set -euo pipefail

selection="${CODING_AGENTS:-}"
[ -n "$selection" ] || exit 0

exec /usr/local/bin/capsule-tools install agents "$selection"
