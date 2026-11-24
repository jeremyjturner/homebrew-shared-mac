#!/bin/bash
# Rebuild all GIFs in docs/images/. Needs: tart, vhs (brew install vhs), a base VM.
# Usage: docs/demo/render.sh [base-vm]   (default: tahoe-base)
# Tapes depend on each other (they run in order inside one VM).
set -euo pipefail
cd "$(dirname "$0")/../.."
docs/demo/prepare.sh "${1:-tahoe-base}"
trap 'tart stop hb-demo || true' EXIT
for tape in docs/demo/0*.tape; do
  echo "== $tape"
  # Never record if the VM is down: the tape would type into the HOST shell.
  tart exec hb-demo true || { echo "VM hb-demo is not running; stop." >&2; exit 1; }
  vhs "$tape"
done
