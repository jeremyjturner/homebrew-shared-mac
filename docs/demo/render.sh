#!/bin/bash
# Rebuild all GIFs in docs/images/. Needs: tart, asciinema and agg (brew install asciinema agg), a base VM.
# Usage: docs/demo/render.sh [base-vm]   (default: ghcr.io/cirruslabs/macos-tahoe-base:latest)
# The clips depend on each other (they run in order inside one VM).
set -euo pipefail
cd "$(dirname "$0")/../.."
docs/demo/prepare.sh "${1:-ghcr.io/cirruslabs/macos-tahoe-base:latest}"
trap 'tart stop hb-demo || true' EXIT
python3 docs/demo/record.py
