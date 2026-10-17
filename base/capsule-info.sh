#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "--tools-summary" ]; then
  img=0
  if [ -x /usr/local/bin/capsule-tools ]; then
    while IFS= read -r c; do
      [ -n "$c" ] || continue
      command -v "$c" >/dev/null 2>&1 && img=$((img + 1))
    done <<EOF
$(/usr/local/bin/capsule-tools commands 2>/dev/null || true)
EOF
  fi
  mise_n=0
  if command -v mise >/dev/null 2>&1; then
    mise_n="$(mise ls --installed -J 2>/dev/null \
      | python3 -c 'import json,sys
try: print(len(json.load(sys.stdin)))
except Exception: print(0)' 2>/dev/null || echo 0)"
  fi
  if [ "$img" -gt 0 ] || [ "$mise_n" -gt 0 ]; then
    printf 'tools: %s image + %s mise — run capsule-info for details\n' "$img" "$mise_n"
  fi
  exit 0
fi

if [ -n "${CAPSULE_INFO:-}" ]; then
  printf '%s\n' "$CAPSULE_INFO"
fi

fmt_table() {
  awk -F'\t' '
    { for (i = 1; i <= NF; i++) { c[NR, i] = $i; if (length($i) > w[i]) w[i] = length($i) } n[NR] = NF }
    END {
      for (r = 1; r <= NR; r++) {
        line = ""
        for (i = 1; i <= n[r]; i++) {
          cell = c[r, i]
          if (i < n[r]) { pad = w[i] - length(cell); line = line cell sprintf("%*s", pad, "") "  " }
          else line = line cell
        }
        print line
      }
    }
  '
}

if [ -f /etc/capsule/info.json ]; then
  cat /etc/capsule/info.json
fi

if [ -x /usr/local/bin/capsule-updates ]; then
  summary="$(/usr/local/bin/capsule-updates --summary 2>/dev/null || true)"
  [ -n "$summary" ] && printf '\n%s\n' "$summary"
fi

if [ -x /usr/local/bin/capsule-tools ]; then
  commands="$(/usr/local/bin/capsule-tools commands 2>/dev/null || true)"
  if [ -n "$commands" ]; then
    printf '\nImage tools (cloud CLIs + agents):\n'
    {
      printf 'COMMAND\tORIGIN\tVERSION\tPATH\n'
      while IFS= read -r c; do
        [ -n "$c" ] || continue
        path="$(command -v "$c" 2>/dev/null || true)"
        if [ -z "$path" ]; then
          printf '%s\t%s\t%s\t%s\n' "$c" "not-installed" "-" "-"
          continue
        fi
        real="$(readlink -f "$path" 2>/dev/null || printf '%s' "$path")"
        case "$path:$real" in
          "$HOME"/.local/share/mise/* | *:"$HOME"/.local/share/mise/*)
            origin="mise-SHADOWING"
            ;;
          "$HOME"/.local/*)
            origin="self-update"
            ;;
          *)
            case "$real" in
              /opt/* | /usr/local/*) origin="image-seed" ;;
              *) origin="system" ;;
            esac
            ;;
        esac
        version="$(timeout 5 "$c" --version 2>/dev/null | head -n1 | tr -d '\r' | cut -c1-32 || true)"
        printf '%s\t%s\t%s\t%s\n' "$c" "$origin" "${version:-?}" "$path"
      done <<EOF
$commands
EOF
    } | fmt_table
  fi
fi

if command -v mise >/dev/null 2>&1; then
  mise_json="$(mise ls --installed -J 2>/dev/null || true)"
  if [ -n "$mise_json" ] && [ "$mise_json" != "{}" ]; then
    rows="$(printf '%s' "$mise_json" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for name, entries in sorted(data.items()):
    for e in entries:
        src = (e.get("source") or {}).get("path", "")
        print("\t".join([name, e.get("version", "?"), src]))
' 2>/dev/null || true)"
    if [ -n "$rows" ]; then
      printf '\nmise tools (declared in mise.toml):\n'
      {
        printf 'TOOL\tVERSION\tSOURCE\n'
        printf '%s\n' "$rows"
      } | fmt_table
    fi
  fi
fi
