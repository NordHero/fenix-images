#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:?usage: check-single-python.sh <image-ref>}"

docker run --rm --entrypoint bash "$IMAGE" -lc '
  set -eu

  expected="/usr/bin/python3"

  resolved_default="$(command -v python3 || true)"
  if [ "$resolved_default" != "$expected" ]; then
    echo "FAIL: python3 resolves to \"$resolved_default\", expected $expected" >&2
    exit 1
  fi

  interpreters=""
  IFS=":"
  for d in $PATH; do
    [ -d "$d" ] || continue
    for f in "$d"/python3 "$d"/python3.[0-9] "$d"/python3.[0-9][0-9]; do
      [ -x "$f" ] || continue
      interpreters="$interpreters
$(readlink -f "$f")"
    done
  done
  unset IFS

  distinct="$(printf "%s" "$interpreters" | sed "/^$/d" | sort -u)"

  bad="$(printf "%s\n" "$distinct" | sed "/^$/d" | grep -v "^/usr/bin/" || true)"
  if [ -n "$bad" ]; then
    echo "FAIL: python3 interpreter(s) on PATH outside /usr/bin (vendor interpreters like /opt/az must stay off PATH):" >&2
    printf "  %s\n" $bad >&2
    exit 1
  fi

  n="$(printf "%s\n" "$distinct" | sed "/^$/d" | wc -l)"
  if [ "$n" -ne 1 ]; then
    echo "FAIL: expected exactly one python3 interpreter on PATH, found $n:" >&2
    printf "  %s\n" $distinct >&2
    exit 1
  fi

  echo "one-python check OK: only $expected on PATH"
'
