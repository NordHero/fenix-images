#!/usr/bin/env bash
set -euo pipefail

selection="${CODING_AGENTS:-}"
[ -n "$selection" ] || exit 0

for tool in $selection; do
  case "$tool" in
    *)
      echo "agents: unknown coding agent '$tool'" >&2
      exit 1
      ;;
  esac
done
