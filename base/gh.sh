#!/bin/bash
[ -f "$HOME/.keyring-env" ] && . "$HOME/.keyring-env"

if [ "${1:-}" = "auth" ] && { [ "${2:-}" = "login" ] || [ "${2:-}" = "refresh" ]; }; then
  insecure=0
  for arg in "$@"; do
    [ "$arg" = "--insecure-storage" ] && insecure=1
  done
  if [ "$insecure" = 0 ] && ! /usr/local/bin/capsule-unlock --status >/dev/null 2>&1; then
    echo "gh: the keyring is locked, so the token would be stored in plaintext." >&2
    echo "gh: run 'capsule-unlock' first, or pass --insecure-storage to accept plaintext storage." >&2
    exit 1
  fi
fi

exec /usr/bin/gh.real "$@"
