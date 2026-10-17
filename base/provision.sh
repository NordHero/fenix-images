#!/usr/bin/env bash
set -uo pipefail

STATE_DIR="$HOME/.provisioned"
REPORT="$STATE_DIR/last-run.log"
STATUS="$STATE_DIR/status"
mkdir -p "$STATE_DIR"

: >"$REPORT"

log() {
  printf '==> %s\n' "$*" | tee -a "$REPORT"
}

marker() {
  printf '%s\n' "$*" | tee -a "$REPORT"
}

mise_ok=skipped
denied_count=0
rc=0

mise_trusted() {
  (cd "$HOME" && mise trust --show 2>/dev/null) | grep -q '^~: trusted$'
}

tools_keys() {
  awk '
    /^[[:space:]]*\[/ { intools = ($0 ~ /^[[:space:]]*\[tools\][[:space:]]*$/) ? 1 : 0; next }
    intools && /=/ {
      key = $0
      sub(/=.*/, "", key)
      gsub(/[[:space:]]/, "", key)
      gsub(/^"|"$/, "", key)
      gsub(/^'"'"'|'"'"'$/, "", key)
      if (key != "") print key
    }
  ' "$1"
}

if [ -f "$HOME/mise.toml" ] && [ "${CAPSULE_TRUST_MISE:-0}" = "1" ]; then
  mise trust "$HOME/mise.toml" >/dev/null 2>&1 || true
fi

if [ -f "$HOME/mise.toml" ] && ! mise_trusted; then
  mise_ok=untrusted
  marker "mise: untrusted; review ~/mise.toml, then run 'mise trust ~/mise.toml && provision.sh' (or set CAPSULE_TRUST_MISE=1)"
elif [ -f "$HOME/mise.toml" ]; then
  eval "$(mise activate bash 2>/dev/null)" || true

  denylist=""
  if [ -x /usr/local/bin/capsule-tools ]; then
    denylist="$(/usr/local/bin/capsule-tools denylist 2>/dev/null || true)"
  fi

  allowed=""
  while IFS= read -r key; do
    [ -n "$key" ] || continue
    if [ -n "$denylist" ] && printf '%s\n' "$denylist" | grep -qxF "$key"; then
      denied_count=$((denied_count + 1))
      marker "mise: denied $key (installed and verified in the cloud-ops/agents layer)"
    else
      allowed="${allowed:+$allowed }$key"
    fi
  done <<EOF
$(tools_keys "$HOME/mise.toml")
EOF

  log "mise install"
  # shellcheck disable=SC2086
  if [ -z "$allowed" ] && [ "$denied_count" -gt 0 ]; then
    mise_ok=ok
    marker "mise: ok (all declared tools denied; nothing installed)"
  elif (cd "$HOME" && mise install --yes $allowed) >>"$REPORT" 2>&1; then
    mise_ok=ok
    marker "mise: ok"
  else
    mise_ok=failed
    rc=1
    marker "mise: failed; run 'mise install' to retry"
  fi
fi

marker "provision: summary mise=$mise_ok denied=$denied_count"
printf 'mise=%s denied=%s rc=%s\n' "$mise_ok" "$denied_count" "$rc" >"$STATUS"

if [ -x /usr/local/bin/capsule-tools ]; then
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    p="$(command -v "$c" 2>/dev/null || true)"
    [ -n "$p" ] || continue
    r="$(readlink -f "$p" 2>/dev/null || printf '%s' "$p")"
    case "$r" in
      "$HOME"/.local/share/mise/*)
        marker "mise: leftover $c at $p shadows the verified copy; run 'mise uninstall' or remove it"
        ;;
    esac
  done <<EOF
$(/usr/local/bin/capsule-tools commands 2>/dev/null || true)
EOF
fi

exit "$rc"
