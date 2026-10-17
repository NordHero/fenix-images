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
rc=0

mise_trusted() {
  (cd "$HOME" && mise trust --show 2>/dev/null) | grep -q '^~: trusted$'
}

if [ -f "$HOME/mise.toml" ] && [ "${CAPSULE_TRUST_MISE:-0}" = "1" ]; then
  mise trust "$HOME/mise.toml" >/dev/null 2>&1 || true
fi

if [ -f "$HOME/mise.toml" ] && ! mise_trusted; then
  mise_ok=untrusted
  marker "mise: untrusted; review ~/mise.toml, then run 'mise trust ~/mise.toml && provision.sh' (or set CAPSULE_TRUST_MISE=1)"
elif [ -f "$HOME/mise.toml" ]; then
  eval "$(mise activate bash 2>/dev/null)" || true
  log "mise install"
  if (cd "$HOME" && mise install --yes) >>"$REPORT" 2>&1; then
    mise_ok=ok
    marker "mise: ok"
  else
    mise_ok=failed
    rc=1
    marker "mise: failed; run 'mise install' to retry"
  fi
fi

marker "provision: summary mise=$mise_ok"
printf 'mise=%s rc=%s\n' "$mise_ok" "$rc" >"$STATUS"

exit "$rc"
