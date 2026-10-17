#!/bin/bash
set -u

[ -x /usr/local/bin/capsule-updates ] || exit 0

(/usr/local/bin/capsule-updates --refresh >/dev/null 2>&1 || true) &

exit 0
