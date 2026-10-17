#!/usr/bin/env bash
set -euo pipefail

TOOLS_DIR="${CAPSULE_TOOLS_DIR:-/usr/local/share/capsule-tools/tools}"

die() {
  echo "capsule-tools: $*" >&2
  exit 1
}

tool_file() {
  printf '%s/%s.sh' "$TOOLS_DIR" "$1"
}

cmd_install() {
  layer="${1:-}"
  selection="${2:-}"
  [ -n "$layer" ] || die "install: missing layer"
  [ -n "$selection" ] || exit 0

  for tool in $selection; do
    file="$(tool_file "$tool")"
    [ -f "$file" ] || die "unknown tool '$tool' (no $file)"
    (
      TOOL_NAME=""
      TOOL_LAYER=""
      # shellcheck source=/dev/null
      . "$file"
      [ "$TOOL_NAME" = "$tool" ] || die "tool '$tool': TOOL_NAME mismatch ('$TOOL_NAME')"
      [ "$TOOL_LAYER" = "$layer" ] || die "tool '$tool': belongs to layer '$TOOL_LAYER', not '$layer'"
      echo "capsule-tools: installing $tool ($layer)" >&2
      tool_install
    )
  done
}

cmd_list() {
  printf '%-12s %-10s %-18s %-8s %s\n' TOOL LAYER ANCHOR SIZE UPDATE
  for file in "$TOOLS_DIR"/*.sh; do
    [ -f "$file" ] || continue
    (
      TOOL_NAME="" TOOL_LAYER="" TOOL_ANCHOR="" TOOL_SIZE="" TOOL_UPDATE=""
      # shellcheck source=/dev/null
      . "$file"
      printf '%-12s %-10s %-18s %-8s %s\n' \
        "$TOOL_NAME" "$TOOL_LAYER" "$TOOL_ANCHOR" "$TOOL_SIZE" "$TOOL_UPDATE"
    )
  done
}

cmd_denylist() {
  for file in "$TOOLS_DIR"/*.sh; do
    [ -f "$file" ] || continue
    (
      TOOL_NAME="" TOOL_MISE_ALIASES=""
      # shellcheck source=/dev/null
      . "$file"
      for a in $TOOL_NAME $TOOL_MISE_ALIASES; do
        printf '%s\n' "$a"
      done
    )
  done | sort -u
}

cmd_commands() {
  for file in "$TOOLS_DIR"/*.sh; do
    [ -f "$file" ] || continue
    (
      TOOL_NAME="" TOOL_COMMANDS=""
      # shellcheck source=/dev/null
      . "$file"
      for c in ${TOOL_COMMANDS:-$TOOL_NAME}; do
        printf '%s\n' "$c"
      done
    )
  done | sort -u
}

cmd="${1:-}"
shift || true
case "$cmd" in
  install) cmd_install "$@" ;;
  list) cmd_list ;;
  denylist) cmd_denylist ;;
  commands) cmd_commands ;;
  *) die "usage: capsule-tools {install <layer> \"<selection>\"|list|denylist|commands}" ;;
esac
