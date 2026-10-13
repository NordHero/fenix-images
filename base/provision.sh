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
extra_ok=skipped
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

  EXTRA_TOOLS="$(sed -n 's/^[[:space:]]*EXTRA_TOOLS[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$HOME/mise.toml")"
  export EXTRA_TOOLS
  if [ -n "${EXTRA_TOOLS:-}" ] && [ -x /usr/local/bin/extra-tools.sh ]; then
    log "extra-tools"
    extra_out="$(/usr/local/bin/extra-tools.sh 2>&1)"
    extra_rc=$?
    printf '%s\n' "$extra_out" >>"$REPORT"
    extra_fail="$(printf '%s\n' "$extra_out" | sed -n 's/.*extra-tools: summary .*failed=\([0-9][0-9]*\).*/\1/p' | tail -n1)"
    if [ "$extra_rc" -eq 0 ] && [ "${extra_fail:-0}" = "0" ]; then
      extra_ok=ok
    else
      extra_ok=failed
      rc=1
    fi
    marker "extra-tools: $extra_ok"
  fi
fi

marker "provision: summary mise=$mise_ok extra-tools=$extra_ok"
printf 'mise=%s extra-tools=%s rc=%s\n' "$mise_ok" "$extra_ok" "$rc" >"$STATUS"

exit "$rc"
