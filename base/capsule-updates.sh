#!/usr/bin/env bash
set -uo pipefail

CACHE_DIR="$HOME/.cache/capsule"
APT_DIR="$CACHE_DIR/apt"
SUMMARY_FILE="$CACHE_DIR/updates.summary"
INFO_JSON="/etc/capsule/info.json"
MAX_AGE_DAYS="${CAPSULE_UPDATE_MAX_AGE_DAYS:-}"

mkdir -p "$CACHE_DIR"

image_age_days() {
  [ -f "$INFO_JSON" ] || {
    echo ""
    return
  }
  bd="$(sed -n 's/.*"build_date"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$INFO_JSON" | head -n1)"
  case "$bd" in
    "" | unknown)
      echo ""
      return
      ;;
  esac
  bts="$(date -u -d "$bd" +%s 2>/dev/null || true)"
  [ -n "$bts" ] || {
    echo ""
    return
  }
  now="$(date -u +%s)"
  echo $(((now - bts) / 86400))
}

count_updates() {
  mkdir -p "$APT_DIR/lists/partial" "$APT_DIR/cache/archives/partial"
  opts="-o Dir::State::Lists=$APT_DIR/lists -o Dir::Cache=$APT_DIR/cache -o Debug::NoLocking=true"
  # shellcheck disable=SC2086
  if ! apt-get $opts update >"$APT_DIR/update.log" 2>&1; then
    echo "ERR"
    return
  fi
  # shellcheck disable=SC2086
  sim="$(apt-get $opts -s upgrade 2>/dev/null || true)"
  total="$(printf '%s\n' "$sim" | grep -c '^Inst ' || true)"
  sec="$(printf '%s\n' "$sim" | grep '^Inst ' | grep -Ec '[-]security' || true)"
  echo "${total} ${sec}"
}

write_summary() {
  age="$1"
  counts="$2"
  if [ "$counts" = "ERR" ]; then
    line="updates: check failed (offline?); rebuild periodically for OS security fixes"
  else
    total="${counts% *}"
    sec="${counts#* }"
    other=$((total - sec))
    if [ "$total" -eq 0 ]; then
      line="updates: up to date"
    else
      line="updates: ${sec} security + ${other} other pending — rebuild your capsule image"
    fi
  fi
  if [ -n "$age" ]; then
    line="${line} (image ${age}d old)"
    if [ -n "$MAX_AGE_DAYS" ] && [ "$age" -gt "$MAX_AGE_DAYS" ] 2>/dev/null; then
      line="${line} ⚠ older than ${MAX_AGE_DAYS}d"
    fi
  fi
  printf '%s\n' "$line" >"$SUMMARY_FILE"
  printf '%s\n' "$line"
}

cmd="${1:-report}"

case "$cmd" in
  --summary)
    if [ -f "$SUMMARY_FILE" ]; then
      cat "$SUMMARY_FILE"
    fi
    ;;
  --refresh | report)
    age="$(image_age_days)"
    counts="$(count_updates)"
    write_summary "$age" "$counts" >/dev/null
    if [ "$cmd" = "report" ]; then
      echo
      if [ "$counts" = "ERR" ]; then
        echo "Could not reach the apt repositories to check for updates."
        echo "This is non-fatal; try again when online."
      elif [ "${counts% *}" -gt 0 ]; then
        echo "Pending apt updates (security first):"
        opts="-o Dir::State::Lists=$APT_DIR/lists -o Dir::Cache=$APT_DIR/cache -o Debug::NoLocking=true"
        # shellcheck disable=SC2086
        apt-get $opts -s upgrade 2>/dev/null | grep '^Inst ' | sed 's/^/  /'
        echo
        echo "Capsules do not apt upgrade at runtime. Rebuild the image to apply:"
        echo "  ./build-images.sh   # or: docker compose build --pull"
      else
        echo "No pending apt updates."
      fi
    fi
    ;;
  *)
    echo "usage: capsule-updates [report|--summary|--refresh]" >&2
    exit 2
    ;;
esac

exit 0
