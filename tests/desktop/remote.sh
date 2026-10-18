#!/usr/bin/env bash
# Runs from your workstation: copies this repository to the AWS test host and runs a command there
# inside the GNOME session environment. Screenshots are pulled back with --pull.
# Usage: tests/desktop/remote.sh HOST KEY 'command'           e.g. './install.sh --profile tahoe'
#        tests/desktop/remote.sh HOST KEY --pull REMOTE_DIR LOCAL_DIR
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
host="${1:?HOST}"; key="${2:?KEY}"; shift 2
ssh_(){ ssh -i "$key" -o StrictHostKeyChecking=accept-new "ubuntu@$host" "$@"; }
if [[ "${1:-}" == --pull ]]; then
  mkdir -p "$3"; ssh_ "tar -C '$2' -cf - ." | tar -C "$3" -xf -; exit 0
fi
tar -C "$ROOT" --exclude=.terraform --exclude='*.tfstate*' --exclude='*.pem' --exclude=docs/test-results -cf - . \
  | ssh_ 'rm -rf ~/ubuntu-tahoe && mkdir -p ~/ubuntu-tahoe && tar -C ~/ubuntu-tahoe -xf -'
ssh_ "cd ~/ubuntu-tahoe && source tests/desktop/session-env.sh && ${1:-true}"
