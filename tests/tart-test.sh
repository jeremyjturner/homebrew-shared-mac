#!/bin/bash
# Test the setup in a throwaway Tart VM. Never touches the host.
# Usage: tests/tart-test.sh [base-vm]   (default: ghcr.io/cirruslabs/macos-tahoe-base:latest)
set -euo pipefail
BASE=${1:-ghcr.io/cirruslabs/macos-tahoe-base:latest}; VM=hb-test; HERE=$(cd "$(dirname "$0")/.." && pwd)
tart delete "$VM" 2>/dev/null || true
tart clone "$BASE" "$VM"
tart run --no-graphics "$VM" >/dev/null 2>&1 &
trap 'tart stop "$VM" || true' EXIT
# tart run starts in the background; wait until the VM is listed as running.
until tart list | grep -q "$VM.*running"; do sleep 2; done
tart ip "$VM" --wait 120 >/dev/null
# Random password for this run only. Nothing secret is stored in the repo.
BOBPW=$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9' | cut -c1-20)
x() { tart exec "$VM" sh -c "$1"; }
check() { if x "$2"; then echo "PASS $1"; else echo "FAIL $1"; exit 1; fi; }
# tart exec does not forward stdin; copy files as base64.
put() { tart exec "$VM" sh -c "echo $(base64 < "$1" | tr -d '\n') | base64 -D > $2"; }
put "$HERE/scripts/brew-wrapper.zsh" /tmp/brew-wrapper.zsh
put "$HERE/scripts/setup.sh" /tmp/setup.sh
x 'chmod +x /tmp/setup.sh'
x "sudo sysadminctl -addUser bob -fullName Bob -UID 502 -admin -password '$BOBPW' 2>/dev/null"
# Interactive prompts through a pty. The base image has passwordless sudo, so switch it off for these.
# pty-test.py puts it back at the end (with the admin password; tart exec has no tty).
x 'sudo mv /etc/sudoers.d/admin-nopasswd /tmp/admin-nopasswd.bak'
python3 "$HERE/tests/pty-test.py" "$VM" admin
# The real setup script, non-interactive: creates the hidden account and changes the owner.
x "cd /tmp && sudo ./setup.sh --yes --owner homebrew --report /tmp/report.txt"
x 'test -s /tmp/report.txt'
x '/opt/homebrew/bin/brew as-brew-user update'
x 'echo "bob ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/zz-test >/dev/null'
# A new login shell must load the wrapper (the script added the line for the admin account).
check "wrapper loads in a new login shell (admin)" 'zsh -ilc "type brew" 2>/dev/null | grep -q "shell function"'
x 'sudo -u bob -H sh -c "echo \"source /usr/local/share/homebrew-shared-mac/brew-wrapper.zsh\" >> ~/.zshrc"'
check "wrapper loads in a new login shell (bob)" 'sudo -u bob -H /bin/zsh -ilc "type brew" 2>/dev/null | grep -q "shell function"'
# Negative control: plain brew doctor as a non-owner shows the misleading chown advice.
check "control: plain brew doctor shows the chown advice" 'sudo -u bob -H /bin/zsh -c "/opt/homebrew/bin/brew doctor 2>&1" | grep -q "should change the ownership"'
# shellcheck disable=SC2016  # \$PATH must expand in the VM, not here
# Through the wrapper, brew doctor runs as the owner and must not show it.
if x 'sudo -u bob -H /bin/zsh -ilc "export PATH=/opt/homebrew/bin:\$PATH; brew doctor 2>&1" || true' | grep -q "should change the ownership"; then echo "FAIL wrapper brew doctor shows the chown advice"; exit 1; else echo "PASS wrapper brew doctor has no chown advice"; fi
# shellcheck disable=SC2016  # \$PATH must expand in the VM, not here
x 'sudo -u bob -H /bin/zsh -c "source /tmp/brew-wrapper.zsh; export PATH=/opt/homebrew/bin:\$PATH; brew install hello && brew uninstall hello"'
# The documented password reset for the hidden account must work.
NEWPW=$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9' | cut -c1-20)
check "documented dscl password reset works" "sudo dscl . -passwd /Users/homebrew '$NEWPW' && dscl . -authonly homebrew '$NEWPW'"
x 'sudo rm /etc/sudoers.d/zz-test'
if [ -z "$(x 'find /opt/homebrew ! -user homebrew | head -1')" ]; then echo "PASS ownership"; else echo "FAIL ownership"; exit 1; fi
