#!/bin/bash
# Test the setup in a throwaway Tart VM. Never touches the host.
# Usage: tests/tart-test.sh [base-vm]   (default: tahoe-base)
set -euo pipefail
BASE=${1:-tahoe-base}; VM=hb-test; HERE=$(cd "$(dirname "$0")/.." && pwd)
tart delete "$VM" 2>/dev/null || true
tart clone "$BASE" "$VM"
tart run --no-graphics "$VM" >/dev/null 2>&1 &
trap 'tart stop "$VM" || true' EXIT
tart ip "$VM" --wait 120 >/dev/null
x() { tart exec "$VM" sh -c "$1"; }
# tart exec does not forward stdin; copy files as base64.
put() { tart exec "$VM" sh -c "echo $(base64 < "$1" | tr -d '\n') | base64 -D > $2"; }
put "$HERE/scripts/brew-wrapper.zsh" /tmp/brew-wrapper.zsh
x 'sudo sysadminctl -addUser bob -fullName Bob -UID 502 -admin -password bobpw'
x 'sudo sysadminctl -addUser homebrew -fullName Homebrew -UID 600 -admin -password hbpw123'
x 'sudo dscl . create /Users/homebrew IsHidden 1; sudo dscl . create /Users/homebrew UserShell /usr/bin/false'
x 'sudo chown -R homebrew:admin /opt/homebrew && sudo chmod -R g-w,o-w /opt/homebrew'
x '/opt/homebrew/bin/brew as-brew-user update'
x 'echo "bob ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/zz-test >/dev/null'
# shellcheck disable=SC2016  # \$PATH must expand in the VM, not here
x 'sudo -u bob -H /bin/zsh -c "source /tmp/brew-wrapper.zsh; export PATH=/opt/homebrew/bin:\$PATH; brew install hello && brew uninstall hello"'
x 'sudo rm /etc/sudoers.d/zz-test'
if [ -z "$(x 'find /opt/homebrew ! -user homebrew | head -1')" ]; then echo "PASS ownership"; else echo "FAIL ownership"; exit 1; fi
