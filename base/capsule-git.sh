#!/usr/bin/env bash
set -uo pipefail

FILE="${CAPSULE_GIT_FILE:-$HOME/.capsule-git.yaml}"
WORKSPACE="${CAPSULE_WORKSPACE:-$HOME/workspace}"
GEN_DIR="$HOME/.config/capsule/git"
GEN_MAIN="$GEN_DIR/config"

DIR_RE='^[A-Za-z0-9_][A-Za-z0-9._-]{0,99}$'
URL_RE='^https://[A-Za-z0-9.-]+(:[0-9]+)?/[^[:space:]]+$'
BRANCH_RE='^[A-Za-z0-9_][A-Za-z0-9._/-]*$'
EMAIL_RE='^[^@[:space:]<>]+@[^@[:space:]<>]+$'

errors=0
FIELD=""
ID_NAME=""
ID_EMAIL=""
GLOBAL_NAME=""
GLOBAL_EMAIL=""
REPO_DIR=()
REPO_URL=()
REPO_BRANCH=()
REPO_NAME=()
REPO_EMAIL=()

say() { printf 'capsule-git: %s\n' "$*" >&2; }
clean() { printf '%s' "$1" | tr -d '[:cntrl:]'; }
err() {
  local where="$1" line
  # Annotate with the source line of the offending node so the user can jump
  # straight to it. The label ("$1") is already a yq path expression, so yq's
  # `line` operator resolves it. Skip "." (the whole-document / parse-error
  # label, which yq always maps to line 1 and which may already carry L..C..).
  if [ "$where" != "." ]; then
    line="$(yq "$where | line" "$FILE" 2>/dev/null)"
    case "$line" in
      '' | 0 | *[!0-9]*) ;;                 # absent/0/non-numeric: no annotation
      *) where="$where (line $line)" ;;
    esac
  fi
  printf 'capsule-git: %s: %s: %s\n' "$FILE" "$where" "$2" >&2
  errors=$((errors + 1))
}
q() { yq "$1" "$FILE" 2>/dev/null; }

is_map() {
  if [ "$(q "$1 | tag")" != "!!map" ]; then
    err "$2" "must be a mapping"
    return 1
  fi
  if [ "$(q "$1 | keys | length")" != "$(q "$1 | keys | unique | length")" ]; then
    err "$2" "duplicate keys"
    return 1
  fi
}

allow_keys() {
  local path="$1" label="$2" n i key a ok keylabel
  shift 2
  n="$(q "$path | length")"
  for ((i = 0; i < n; i++)); do
    key="$(q "$path | to_entries | .[$i] | .key")"
    ok=0
    for a in "$@"; do
      [ "$key" = "$a" ] && ok=1
    done
    if [ "$ok" != 1 ]; then
      # Point at the offending key's own line, not the parent mapping.
      if [ "$label" = "." ]; then keylabel=".$key"; else keylabel="$label.$key"; fi
      err "$keylabel" "unknown key '$(clean "$key")'"
    fi
  done
}

has() { [ "$(q "$1 | has(\"$2\")")" = "true" ]; }

field() {
  local p="$1 | .[\"$2\"]" label="$3" value
  FIELD=""
  has "$1" "$2" || return 1
  if [ "$(q "$p | tag")" != "!!str" ]; then
    err "$label" "must be a string"
    return 2
  fi
  if [ "$(q "$p | test(\"[[:cntrl:]]\")")" != "false" ]; then
    err "$label" "must not contain control characters"
    return 2
  fi
  value="$(q "$p")"
  if [ -z "$value" ]; then
    err "$label" "must not be empty"
    return 2
  fi
  FIELD="$value"
}

identity() {
  local path="$1" label="$2"
  ID_NAME=""
  ID_EMAIL=""
  is_map "$path" "$label" || return
  allow_keys "$path" "$label" name email
  field "$path" name "$label.name" && ID_NAME="$FIELD"
  if field "$path" email "$label.email"; then
    if [[ "$FIELD" =~ $EMAIL_RE ]]; then
      ID_EMAIL="$FIELD"
    else
      err "$label.email" "not an email address"
    fi
  fi
}

repo() {
  local i="$1" key path label url branch="" rc
  key="$(q ".repos | to_entries | .[$i] | .key")"
  if [ "$(q ".repos | to_entries | .[$i] | .key | tag")" != "!!str" ] || ! [[ "$key" =~ $DIR_RE ]]; then
    err ".repos[$i]" "dir '$(clean "$key")' must be a string matching $DIR_RE"
    return
  fi
  path=".repos | to_entries | .[$i] | .value"
  label=".repos.$key"
  is_map "$path" "$label" || return
  allow_keys "$path" "$label" url branch identity
  field "$path" url "$label.url"
  rc=$?
  url="$FIELD"
  if [ "$rc" = 1 ]; then
    err "$label.url" "required"
  elif [ "$rc" = 0 ] && ! [[ "$url" =~ $URL_RE ]]; then
    err "$label.url" "must be an https:// URL"
  fi
  if field "$path" branch "$label.branch"; then
    branch="$FIELD"
    if ! [[ "$branch" =~ $BRANCH_RE ]] || [[ "$branch" == *..* ]] || [[ "$branch" == */ ]]; then
      err "$label.branch" "not a valid branch name"
    fi
  fi
  ID_NAME=""
  ID_EMAIL=""
  has "$path" identity && identity "$path | .identity" "$label.identity"
  REPO_DIR+=("$key")
  REPO_URL+=("$url")
  REPO_BRANCH+=("$branch")
  REPO_NAME+=("$ID_NAME")
  REPO_EMAIL+=("$ID_EMAIL")
}

validate() {
  local msg n i
  if ! command -v yq >/dev/null 2>&1; then
    say "yq not found"
    return 1
  fi
  if ! msg="$(yq '.' "$FILE" 2>&1 >/dev/null)"; then
    # yq reports e.g. "Error: bad file '<path>': go-yaml load error in
    # scanner at L18.C11: mapping values are not allowed in this context".
    # Strip yq's path/lead-in noise but keep the "L..C.." location so the
    # user knows which line to fix (the old ${msg##*: } dropped it).
    msg="${msg#Error: }"
    case "$msg" in
      "bad file '"*"': "*) msg="${msg#bad file \'*\': }" ;;
    esac
    msg="${msg#go-yaml load error in }"
    err "." "not valid YAML ($(clean "$msg"))"
    return 1
  fi
  if [ "$(yq ea '[.] | length' "$FILE" 2>/dev/null)" != "1" ]; then
    err "." "must be a single YAML document"
    return 1
  fi
  if [ "$(q '[.. | select(anchor != "" or tag == "")] | length')" != "0" ]; then
    err "." "anchors and aliases are not supported"
    return 1
  fi
  is_map "." "." || return 1
  allow_keys "." "." version identity repos
  if [ "$(q '.version | tag')" != "!!int" ] || [ "$(q '.version')" != "1" ]; then
    err ".version" "must be 1"
    return 1
  fi
  if has "." identity; then
    identity ".identity" ".identity"
    GLOBAL_NAME="$ID_NAME"
    GLOBAL_EMAIL="$ID_EMAIL"
  fi
  if has "." repos && is_map ".repos" ".repos"; then
    n="$(q '.repos | length')"
    for ((i = 0; i < n; i++)); do
      repo "$i"
    done
  fi
  [ "$errors" -eq 0 ]
}

warn_env() {
  local v
  for v in CAPSULE_REPOS CAPSULE_REPOS_FILE GIT_USER_NAME GIT_USER_EMAIL; do
    [ -n "${!v:-}" ] && say "$v is no longer supported and is ignored; declare it in $FILE"
  done
}

include_main() {
  git config --global --fixed-value --unset-all include.path "$GEN_MAIN" 2>/dev/null
  git config --global --add include.path "$GEN_MAIN"
}

apply() {
  local i f
  warn_env
  rm -rf "$GEN_DIR"
  include_main || return 1
  [ -f "$FILE" ] || return 0
  if ! validate; then
    mkdir -p "$GEN_DIR" && : >"$GEN_DIR/invalid"
    say "git identity not applied; fix $FILE (run: capsule-git check)"
    return 1
  fi
  mkdir -p "$GEN_DIR"
  : >"$GEN_MAIN"
  [ -n "$GLOBAL_NAME" ] && git config --file "$GEN_MAIN" user.name "$GLOBAL_NAME"
  [ -n "$GLOBAL_EMAIL" ] && git config --file "$GEN_MAIN" user.email "$GLOBAL_EMAIL"
  for i in "${!REPO_DIR[@]}"; do
    [ -z "${REPO_NAME[$i]}${REPO_EMAIL[$i]}" ] && continue
    f="$GEN_DIR/repo-${REPO_DIR[$i]}.config"
    : >"$f"
    [ -n "${REPO_NAME[$i]}" ] && git config --file "$f" user.name "${REPO_NAME[$i]}"
    [ -n "${REPO_EMAIL[$i]}" ] && git config --file "$f" user.email "${REPO_EMAIL[$i]}"
    git config --file "$GEN_MAIN" "includeIf.gitdir:$WORKSPACE/${REPO_DIR[$i]}/.path" "$f"
  done
  return 0
}

repos() {
  local i
  [ -f "$FILE" ] || return 0
  validate || return 1
  for i in "${!REPO_DIR[@]}"; do
    printf '%s\037%s\037%s\n' "${REPO_DIR[$i]}" "${REPO_URL[$i]}" "${REPO_BRANCH[$i]}"
  done
}

check() {
  if [ ! -f "$FILE" ]; then
    say "no $FILE"
    return 0
  fi
  validate || return 1
  printf 'capsule-git: %s: ok (identity: %s, repos: %s)\n' "$FILE" \
    "$([ -n "$GLOBAL_NAME$GLOBAL_EMAIL" ] && echo set || echo unset)" "${#REPO_DIR[@]}"
}

case "${1:-}" in
  check) check ;;
  apply) apply ;;
  repos) repos ;;
  *)
    echo "usage: capsule-git check | apply | repos" >&2
    exit 2
    ;;
esac
