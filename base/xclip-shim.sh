#!/bin/bash
mode="out"
for arg in "$@"; do
  case "$arg" in
    -i|-in) mode="in" ;;
    -o|-out) mode="out" ;;
  esac
done
if [ "$mode" = "in" ]; then
  cat >/dev/null
else
  printf ''
fi
exit 0
