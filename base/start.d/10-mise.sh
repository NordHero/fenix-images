#!/bin/bash
set -u

[ -f "$HOME/mise.toml" ] || exit 0
[ -x /usr/local/bin/provision.sh ] || exit 0

if /usr/local/bin/provision.sh; then
  exit 0
fi

echo "provision: incomplete; run 'provision.sh' to retry (see ~/.provisioned/last-run.log)" >&2
exit 1
