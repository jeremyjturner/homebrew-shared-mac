#!/bin/bash
# Make a fresh demo VM: Homebrew installed, one admin user, one second admin user.
# Usage: docs/demo/prepare.sh [base-vm]   (default: ghcr.io/cirruslabs/macos-tahoe-base:latest)
set -euo pipefail
BASE=${1:-ghcr.io/cirruslabs/macos-tahoe-base:latest}; VM=hb-demo; HERE=$(cd "$(dirname "$0")/../.." && pwd)
tart stop "$VM" 2>/dev/null || true
tart delete "$VM" 2>/dev/null || true
tart clone "$BASE" "$VM"
tart run --no-graphics "$VM" >/dev/null 2>&1 < /dev/null &
# tart run returns before the VM is up: wait until it is listed as running.
until tart list | grep -q "$VM.*running"; do sleep 2; done
tart ip "$VM" --wait 120 >/dev/null
# Copy the repo scripts into the VM (base64: robust through tart exec).
tar -C "$HERE" -c scripts | base64 | tr -d '\n' > "${TMPDIR:-/tmp}/hb-demo.b64"
tart exec "$VM" sh -c "mkdir -p ~/homebrew-shared-mac && echo $(cat "${TMPDIR:-/tmp}/hb-demo.b64") | base64 -D | tar -x -C ~/homebrew-shared-mac"
rm -f "${TMPDIR:-/tmp}/hb-demo.b64"
# The second user. Both users are admins with a password, like a real shared Mac.
tart exec "$VM" sh -c 'sudo sysadminctl -addUser bob -fullName Bob -UID 502 -admin -password bobpw 2>/dev/null'
# Remove the passwordless sudo of the base image so that password prompts are real.
# The base image admin password is "admin".
tart exec "$VM" sh -c 'sudo rm -f /etc/sudoers.d/admin-nopasswd'
echo "VM $VM is running. Next: docs/demo/render.sh"
