#!/usr/bin/env bash
set -uo pipefail

PREFIX="$HOME/.local"
BIN="$PREFIX/bin"
MARKERS="$HOME/.provisioned"
mkdir -p "$BIN" "$MARKERS"
export PATH="$BIN:$PATH"

STRICT="${EXTRA_TOOLS_STRICT:-0}"

log() { printf '==> %s\n' "$*"; }
installed() { [ -f "$MARKERS/$1" ]; }
mark() { : >"$MARKERS/$1"; }
latest_only() { log "note: $1 installs the vendor's latest; version pinning is not supported by its installer"; }

install_kiro-cli() {
  local version="$1"
  installed kiro-cli && {
    log "kiro-cli: already installed"
    return
  }
  [ "$version" != "latest" ] && latest_only kiro-cli
  log "installing kiro-cli"
  rm -f "$BIN/kiro-cli" "$BIN/kiro-cli-chat" "$BIN/kiro-cli-term" \
    "$BIN/q" "$BIN/qchat" "$BIN/qterm"
  KIRO_CLI_SKIP_SETUP=1 bash -c 'curl -fsSL https://cli.kiro.dev/install | bash'
  if [ ! -x "$BIN/kiro-cli" ]; then
    log "kiro-cli: install did not produce $BIN/kiro-cli"
    return 1
  fi
  mark kiro-cli
}

install_one() {
  local entry="$1" tool version
  tool="${entry%@*}"
  version="latest"
  [ "$entry" != "$tool" ] && version="${entry#*@}"
  case "$tool" in
    kiro-cli) "install_kiro-cli" "$version" ;;
    *)
      log "unknown extra tool: $tool"
      return 2
      ;;
  esac
}

ok_count=0
failed_count=0
failed_list=""

for entry in ${EXTRA_TOOLS:-}; do
  if (install_one "$entry"); then
    printf 'extra-tool: %s: ok\n' "$entry"
    ok_count=$((ok_count + 1))
  else
    status=$?
    if [ "$status" -eq 2 ]; then
      printf 'extra-tool: %s: unknown\n' "$entry"
    else
      printf 'extra-tool: %s: failed\n' "$entry"
    fi
    failed_count=$((failed_count + 1))
    failed_list="${failed_list:+$failed_list }$entry"
  fi
done

printf 'extra-tools: summary ok=%s failed=%s%s\n' \
  "$ok_count" "$failed_count" "${failed_list:+ (failed: $failed_list)}"

if [ "$failed_count" -gt 0 ] && [ "$STRICT" = "1" ]; then
  exit 1
fi
exit 0
