#!/usr/bin/env bash
set -uo pipefail

WORKSPACE="${CAPSULE_WORKSPACE:-$HOME/workspace}"
MANIFEST="${CAPSULE_REPOS_FILE:-$HOME/.capsule-repos}"
export GIT_TERMINAL_PROMPT=0

mkdir -p "$WORKSPACE"

log() { printf '==> %s\n' "$*"; }

cloned=0
skipped=0
failed=0
failed_list=""

clone_one() {
  local url="$1" dir="$2" branch="$3" target
  target="$WORKSPACE/$dir"
  if [ -e "$target" ]; then
    printf 'repo: %s: skipped (exists)\n' "$dir"
    skipped=$((skipped + 1))
    return 0
  fi
  local args=(clone)
  [ -n "$branch" ] && args+=(--branch "$branch")
  args+=("$url" "$target")
  if git "${args[@]}" >/dev/null 2>&1; then
    printf 'repo: %s: cloned\n' "$dir"
    cloned=$((cloned + 1))
  else
    printf 'repo: %s: failed (is gh authenticated? run: gh auth login)\n' "$dir"
    failed=$((failed + 1))
    failed_list="${failed_list:+$failed_list }$dir"
  fi
}

for entry in ${CAPSULE_REPOS:-}; do
  case "$entry" in
    */*)
      clone_one "https://github.com/${entry}.git" "${entry##*/}" ""
      ;;
    *)
      printf 'repo: %s: failed (expected owner/repo)\n' "$entry"
      failed=$((failed + 1))
      failed_list="${failed_list:+$failed_list }$entry"
      ;;
  esac
done

if [ -f "$MANIFEST" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    set -- $line
    [ "$#" -eq 0 ] && continue
    url="$1"
    dir="${2:-}"
    branch="${3:-}"
    if [ -z "$dir" ]; then
      dir="${url##*/}"
      dir="${dir%.git}"
    fi
    clone_one "$url" "$dir" "$branch"
  done <"$MANIFEST"
fi

if [ "$((cloned + skipped + failed))" -eq 0 ]; then
  log "no repos declared (set CAPSULE_REPOS or mount ~/.capsule-repos)"
  exit 0
fi

printf 'capsule-sync: summary cloned=%s skipped=%s failed=%s%s\n' \
  "$cloned" "$skipped" "$failed" "${failed_list:+ (failed: $failed_list)}"

[ "$failed" -gt 0 ] && exit 1
exit 0
