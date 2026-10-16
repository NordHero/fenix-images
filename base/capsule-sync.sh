#!/usr/bin/env bash
set -uo pipefail
set -f

WORKSPACE="${CAPSULE_WORKSPACE:-$HOME/workspace}"
GIT_FILE="${CAPSULE_GIT_FILE:-$HOME/.capsule-git.yaml}"
LEGACY="$HOME/.capsule-repos"
DIR_RE='^[A-Za-z0-9_][A-Za-z0-9._-]{0,99}$'
export GIT_TERMINAL_PROMPT=0

mkdir -p "$WORKSPACE"

log() { printf '==> %s\n' "$*"; }

cloned=0
skipped=0
failed=0
failed_list=""

fail_one() {
  printf 'repo: %s: failed (%s)\n' "$1" "$2"
  failed=$((failed + 1))
  failed_list="${failed_list:+$failed_list }$1"
}

clone_one() {
  local url="$1" dir="$2" branch="$3" target
  local ssh=0 hint="is gh authenticated? run: gh auth login"
  case "$url" in
    https://*) ;;
    git@github.com:*)
      if [ "${CAPSULE_GIT_SSH:-}" != "1" ]; then
        fail_one "$dir" "SSH URLs need CAPSULE_GIT_SSH=1"
        return 0
      fi
      ssh=1
      hint="is the key in the forwarded agent? run: ssh-add -l"
      ;;
    *)
      fail_one "$dir" "only https:// and git@github.com: URLs are allowed"
      return 0
      ;;
  esac
  if ! [[ "$dir" =~ $DIR_RE ]]; then
    fail_one "$dir" "unsafe directory name"
    return 0
  fi
  target="$WORKSPACE/$dir"
  if [ -e "$target" ]; then
    printf 'repo: %s: skipped (exists)\n' "$dir"
    skipped=$((skipped + 1))
    return 0
  fi
  local args=(clone)
  [ -n "$branch" ] && args+=(--branch "$branch")
  args+=(-- "$url" "$target")
  if [ "$ssh" = 1 ]; then
    GIT_SSH_COMMAND="ssh -o BatchMode=yes" git "${args[@]}" >/dev/null 2>&1
  else
    git "${args[@]}" >/dev/null 2>&1
  fi
  if [ "$?" -eq 0 ]; then
    printf 'repo: %s: cloned\n' "$dir"
    cloned=$((cloned + 1))
  else
    fail_one "$dir" "$hint"
  fi
}

[ -n "${CAPSULE_REPOS:-}" ] && log "CAPSULE_REPOS is no longer supported and is ignored; declare repos in $GIT_FILE"

if [ -f "$GIT_FILE" ]; then
  if list="$(/usr/local/bin/capsule-git repos)"; then
    while IFS=$'\037' read -r dir url branch; do
      [ -z "$dir" ] && continue
      clone_one "$url" "$dir" "$branch"
    done <<<"$list"
  else
    fail_one "${GIT_FILE##*/}" "invalid; run: capsule-git check"
  fi
fi

if [ -f "$LEGACY" ]; then
  log "$LEGACY is deprecated and will be removed; move its repos to $GIT_FILE"
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
  done <"$LEGACY"
fi

if [ "$((cloned + skipped + failed))" -eq 0 ]; then
  log "no repos declared (add repos to $GIT_FILE)"
  exit 0
fi

printf 'capsule-sync: summary cloned=%s skipped=%s failed=%s%s\n' \
  "$cloned" "$skipped" "$failed" "${failed_list:+ (failed: $failed_list)}"

[ "$failed" -gt 0 ] && exit 1
exit 0
