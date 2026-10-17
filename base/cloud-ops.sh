#!/usr/bin/env bash
set -euo pipefail

selection="${CLOUD_CLIS:-}"
[ -n "$selection" ] || exit 0

for tool in $selection; do
  case "$tool" in
    *)
      echo "cloud-ops: unknown CLI '$tool'" >&2
      exit 1
      ;;
  esac
done
