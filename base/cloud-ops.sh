#!/usr/bin/env bash
set -euo pipefail

selection="${CLOUD_CLIS:-}"
[ -n "$selection" ] || exit 0

exec /usr/local/bin/capsule-tools install cloud-ops "$selection"
