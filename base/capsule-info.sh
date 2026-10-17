#!/usr/bin/env bash
set -euo pipefail

if [ -n "${CAPSULE_INFO:-}" ]; then
  printf '%s\n' "$CAPSULE_INFO"
fi

if [ -f /etc/capsule/info.json ]; then
  cat /etc/capsule/info.json
fi

if [ -x /usr/local/bin/capsule-tools ]; then
  commands="$(/usr/local/bin/capsule-tools commands 2>/dev/null || true)"
  if [ -n "$commands" ]; then
    printf '\nRegistered tools:\n'
    printf '%-12s %-30s %-6s %-16s %s\n' COMMAND PATH OWNER ORIGIN VERSION
    while IFS= read -r c; do
      [ -n "$c" ] || continue
      path="$(command -v "$c" 2>/dev/null || true)"
      if [ -z "$path" ]; then
        printf '%-12s %-30s %-6s %-16s %s\n' "$c" "(not on PATH)" "-" "-" "-"
        continue
      fi
      real="$(readlink -f "$path" 2>/dev/null || printf '%s' "$path")"
      owner="$(stat -c '%U' "$real" 2>/dev/null || echo '?')"
      case "$real" in
        "$HOME"/.local/share/mise/*) origin="mise(shadowing!)" ;;
        "$HOME"/*) origin="self-update" ;;
        /opt/* | /usr/local/*) origin="image-seed" ;;
        *) origin="system" ;;
      esac
      version="$(timeout 5 "$c" --version 2>/dev/null | head -n1 | tr -d '\r' | cut -c1-40 || true)"
      printf '%-12s %-30s %-6s %-16s %s\n' "$c" "$path" "$owner" "$origin" "${version:-?}"
    done <<EOF
$commands
EOF
  fi
fi
