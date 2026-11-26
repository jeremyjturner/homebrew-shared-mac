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
# Bob sets a per-user cask folder, like a real user may do. The wrapper ignores it (clean environment).
x "sudo -u bob -H sh -c 'mkdir -p ~/Applications && echo export HOMEBREW_CASK_OPTS=\\\"--appdir=~/Applications\\\" > ~/.zshrc'"
# Before the fix: the admin owns Homebrew and installs a cask into bob's ~/Applications (the old --appdir way).
x 'sudo chmod 777 /Users/bob/Applications'
x '/opt/homebrew/bin/brew install --cask --appdir=/Users/bob/Applications rectangle'
check "setup: the cask app is in bob's ~/Applications" 'test -d /Users/bob/Applications/Rectangle.app'
# Steam asks for sudo when brew removes it (launchctl). The hidden account has no password, so the
# script must allow sudo for it during the move.
x '/opt/homebrew/bin/brew install --cask --appdir=/Users/bob/Applications steam'
check "setup: steam is in bob's ~/Applications" 'test -d /Users/bob/Applications/Steam.app'
x 'cd /tmp && sudo ./setup.sh --check --report /tmp/report-before.txt'
check "report flags bob's HOMEBREW_CASK_OPTS --appdir" 'grep -q "bob  .zshrc: export HOMEBREW_CASK_OPTS" /tmp/report-before.txt'
check "report lists the cask app in bob's ~/Applications" 'grep -q "bob  rectangle  /Users/bob/Applications/Rectangle.app" /tmp/report-before.txt'
# Interactive prompts through a pty. The base image has passwordless sudo, so switch it off for these.
# pty-test.py puts it back at the end (with the admin password; tart exec has no tty).
x 'sudo mv /etc/sudoers.d/admin-nopasswd /tmp/admin-nopasswd.bak'
python3 "$HERE/tests/pty-test.py" "$VM" admin
# The real setup script, non-interactive: creates the hidden account and changes the owner.
x "cd /tmp && sudo ./setup.sh --yes --owner homebrew --report /tmp/report.txt 2>&1 | tee /tmp/setup-out.txt"
check "setup output has no brew sudo-domain warning or env hint" '! grep -q "gui/\*\|Hide these hints" /tmp/setup-out.txt'
x 'test -s /tmp/report.txt'
x '/opt/homebrew/bin/brew as-brew-user update'
x 'echo "bob ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/zz-test >/dev/null'
# A new login shell must load the wrapper (the script added the line for the admin account).
check "wrapper loads in a new login shell (admin)" 'zsh -ilc "type brew" 2>/dev/null | grep -q "shell function"'
check "script added the wrapper to bob's ~/.zshrc" 'sudo grep -q "^source /usr/local/share/homebrew-shared-mac/brew-wrapper.zsh" /Users/bob/.zshrc'
check "script turned off bob's --appdir line" 'sudo grep -q "^# homebrew-shared-mac disabled: export HOMEBREW_CASK_OPTS" /Users/bob/.zshrc && ! sudo grep -q "^export HOMEBREW_CASK_OPTS" /Users/bob/.zshrc'
check "cask app moved to /Applications and is gone from bob's ~/Applications" 'test -d /Applications/Rectangle.app && ! test -e /Users/bob/Applications/Rectangle.app'
check "steam (needs sudo to uninstall) moved to /Applications" 'test -d /Applications/Steam.app && ! test -e /Users/bob/Applications/Steam.app'
check "the temporary sudo rule is removed" '! test -e /etc/sudoers.d/homebrew-shared-mac-temp && ! ls /etc/sudoers.d | grep -q "homebrew-shared-mac"'
check "brew still manages the cask" '/opt/homebrew/bin/brew list --cask rectangle | grep -q "/Applications/Rectangle.app\|Rectangle.app"'
check "old app is kept in the backup folder" 'sudo find /usr/local/share/homebrew-shared-mac/backups -name Rectangle.app | grep -q .'
check "wrapper loads in a new login shell (bob)" 'sudo -u bob -H /bin/zsh -ilc "type brew" 2>/dev/null | grep -q "shell function"'
# An old wrapper (for example one with the working-folder bug) must be found and replaced.
x 'echo "# old wrapper" | sudo tee /usr/local/share/homebrew-shared-mac/brew-wrapper.zsh >/dev/null'
check "--check flags an out-of-date wrapper" 'cd /tmp && sudo ./setup.sh --check --report /tmp/report-stale.txt 2>&1 | grep -q "wrapper is out of date"'
x "cd /tmp && sudo ./setup.sh --yes --owner homebrew --report /tmp/report-stale2.txt"
check "setup replaces the out-of-date wrapper" 'cmp -s /tmp/brew-wrapper.zsh /usr/local/share/homebrew-shared-mac/brew-wrapper.zsh'
# Regression: an app in /Applications that a person owns (installed by an old setup). The owner
# account cannot write there, so brew asked for a sudo password that nobody knows.
x 'sudo chown -R bob /Applications/Rectangle.app'
check "--check flags a brew app that another account owns" 'cd /tmp && sudo ./setup.sh --check --report /tmp/report-foreign.txt 2>&1 | grep -q "another account owns"'
x "cd /tmp && sudo ./setup.sh --yes --owner homebrew --report /tmp/report-foreign2.txt"
# shellcheck disable=SC2016  # $(stat) must run in the VM, not here
check "setup gives the app to the hidden account" 'test "$(stat -f %Su /Applications/Rectangle.app)" = homebrew'
check "brew can reinstall the app without a sudo password" 'cd /tmp && /opt/homebrew/bin/brew as-brew-user reinstall --cask rectangle < /dev/null'
# Regression: an "adopted" cask. The Caskroom holds a real copy of the app instead of a link,
# and "brew upgrade" stops with "already an App at". Fake it, then let the script fix it.
# shellcheck disable=SC2016  # must expand in the VM, not here
x 'cd /tmp && C=$(ls -d /opt/homebrew/Caskroom/rectangle/*/ | head -1) && sudo rm "${C}Rectangle.app" && sudo cp -R /Applications/Rectangle.app "${C}Rectangle.app" && sudo chown -R bob /Applications/Rectangle.app'
check "--check flags a cask with a second copy in the Caskroom" 'cd /tmp && sudo ./setup.sh --check --report /tmp/report-adopted.txt 2>&1 | grep -q "second copy"'
x "cd /tmp && sudo ./setup.sh --yes --owner homebrew --report /tmp/report-adopted2.txt"
check "setup turns the Caskroom copy into a link" 'test -L /opt/homebrew/Caskroom/rectangle/*/Rectangle.app'
# shellcheck disable=SC2016  # $(stat) must run in the VM, not here
check "setup gives the adopted app to the hidden account" 'test "$(stat -f %Su /Applications/Rectangle.app)" = homebrew'
# Rollback of this fix: the second copy comes back, then the script fixes it again.
x "cd /tmp && sudo ./setup.sh --rollback --yes"
# shellcheck disable=SC2016  # glob must expand in the VM, not here
check "rollback puts the second copy back in the Caskroom" 'test -d /opt/homebrew/Caskroom/rectangle/*/Rectangle.app && ! test -L /opt/homebrew/Caskroom/rectangle/*/Rectangle.app'
x "cd /tmp && sudo ./setup.sh --yes --owner homebrew --report /tmp/report-adopted3.txt"
check "setup turns the Caskroom copy into a link again" 'test -L /opt/homebrew/Caskroom/rectangle/*/Rectangle.app'
check "brew upgrade --force works on the fixed cask" 'cd /tmp && /opt/homebrew/bin/brew as-brew-user reinstall --cask rectangle < /dev/null'
# Negative control: plain brew doctor as a non-owner shows the misleading chown advice.
check "control: plain brew doctor shows the chown advice" 'sudo -u bob -H /bin/zsh -c "/opt/homebrew/bin/brew doctor 2>&1" | grep -q "should change the ownership"'
# shellcheck disable=SC2016  # \$PATH must expand in the VM, not here
# Through the wrapper, brew doctor runs as the owner and must not show it.
if x 'sudo -u bob -H /bin/zsh -ilc "export PATH=/opt/homebrew/bin:\$PATH; brew doctor 2>&1" || true' | grep -q "should change the ownership"; then echo "FAIL wrapper brew doctor shows the chown advice"; exit 1; else echo "PASS wrapper brew doctor has no chown advice"; fi
# shellcheck disable=SC2016  # \$PATH must expand in the VM, not here
x 'sudo -u bob -H /bin/zsh -c "source /tmp/brew-wrapper.zsh; export PATH=/opt/homebrew/bin:\$PATH; brew install hello && brew uninstall hello"'
# Regression: a folder the owner cannot enter (like a repo in the home folder) must not break brew.
# shellcheck disable=SC2016  # \$PATH must expand in the VM, not here
if x 'sudo -u bob -H /bin/zsh -c "mkdir -p -m 700 ~/private && cd ~/private && source /tmp/brew-wrapper.zsh && export PATH=/opt/homebrew/bin:\$PATH && brew update"'; then echo 'PASS wrapper works from a private folder'; else echo 'FAIL wrapper from a private folder'; exit 1; fi
# HOMEBREW_CASK_OPTS --appdir: the report must flag it, and a cask installed through the wrapper
# must land in /Applications, not in bob's ~/Applications.
# shellcheck disable=SC2016  # \$PATH must expand in the VM, not here
x 'sudo -u bob -H /bin/zsh -c "source /tmp/brew-wrapper.zsh; export PATH=/opt/homebrew/bin:\$PATH; brew uninstall --cask rectangle"'
# shellcheck disable=SC2016  # \$PATH must expand in the VM, not here
x 'sudo -u bob -H /bin/zsh -c "source /tmp/brew-wrapper.zsh; export HOMEBREW_CASK_OPTS=--appdir=/Users/bob/Applications PATH=/opt/homebrew/bin:\$PATH; brew install --cask rectangle"'
check "cask lands in /Applications despite bob's --appdir" 'test -d /Applications/Rectangle.app && ! test -e /Users/bob/Applications/Rectangle.app'
# shellcheck disable=SC2016  # \$PATH must expand in the VM, not here
x 'sudo -u bob -H /bin/zsh -c "source /tmp/brew-wrapper.zsh; export PATH=/opt/homebrew/bin:\$PATH; brew uninstall --cask rectangle"'
# The documented password reset for the hidden account must work.
NEWPW=$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9' | cut -c1-20)
check "documented dscl password reset works" "sudo dscl . -passwd /Users/homebrew '$NEWPW' && dscl . -authonly homebrew '$NEWPW'"
x 'sudo rm /etc/sudoers.d/zz-test'
# One password for `brew update-all` (the second user's own sudo password, no sudoers rule).
python3 "$HERE/tests/pty-update-all.py" "$VM" bob "$BOBPW"
if [ -z "$(x 'find /opt/homebrew ! -user homebrew | head -1')" ]; then echo "PASS ownership"; else echo "FAIL ownership"; exit 1; fi
# Script rollback: undoes the account, owner, wrapper lines, --appdir line and moved apps.
# The newest backup is the adopted-cask fix, then the app-owner change, then the main setup.
x "cd /tmp && sudo ./setup.sh --rollback --yes"
x "cd /tmp && sudo ./setup.sh --rollback --yes"
x "cd /tmp && sudo ./setup.sh --rollback --yes"
check "script rollback: the old app is back in bob's ~/Applications" 'test -d /Users/bob/Applications/Rectangle.app'
check "script rollback: hidden account is gone" '! dscl . -read /Users/homebrew >/dev/null 2>&1'
# shellcheck disable=SC2016  # $(whoami) must expand in the VM, not here
check "script rollback: the admin owns the prefix" 'test -z "$(find /opt/homebrew ! -user "$(whoami)" | head -1)"'
check "script rollback: no wrapper line in admin or bob" '! grep -q brew-wrapper ~/.zshrc && ! sudo grep -q brew-wrapper /Users/bob/.zshrc'
check "script rollback: bob's --appdir line is active again" 'sudo grep -q "^export HOMEBREW_CASK_OPTS" /Users/bob/.zshrc'
check "script rollback: the backup is marked as used" 'sudo find /usr/local/share/homebrew-shared-mac/backups -name "*.rolled-back" | grep -q .'
check "script rollback: brew install works for the admin without sudo" 'zsh -ilc "brew install hello && brew uninstall hello"'
x "cd /tmp && sudo ./setup.sh --yes --owner homebrew --report /tmp/report2.txt"
# A failed cask reinstall must put the old app back and say what state brew is in.
# A plain folder already at the target path makes brew's install step fail (offline, no network trick).
x 'sudo chmod 777 /Users/bob/Applications && cd /tmp && /opt/homebrew/bin/brew as-brew-user install --cask --appdir=/Users/bob/Applications keepingyouawake < /dev/null'
check "failed reinstall: the test app is in bob's ~/Applications" 'test -d "/Users/bob/Applications/KeepingYouAwake.app"'
x 'sudo mkdir -p /Applications/KeepingYouAwake.app && sudo touch /Applications/KeepingYouAwake.app/blocker'
x "cd /tmp && sudo ./setup.sh --yes --owner homebrew --report /tmp/report3.txt < /dev/null 2>&1 | tee /tmp/setup-fail.txt; true"
x 'sudo rm -rf /Applications/KeepingYouAwake.app'
check "failed reinstall: the script says it failed" "grep -q \"Reinstall of 'keepingyouawake' failed\" /tmp/setup-fail.txt"
check "failed reinstall: the script names the brew state and the fix" 'grep -q "brew reinstall --cask --appdir=/Applications keepingyouawake\|brew install --cask --appdir=/Applications keepingyouawake" /tmp/setup-fail.txt'
check "failed reinstall: the old app is back" 'test -d "/Users/bob/Applications/KeepingYouAwake.app"'
x 'sudo rm -rf /Users/bob/Applications/KeepingYouAwake.app; cd /tmp && /opt/homebrew/bin/brew as-brew-user uninstall --cask --force keepingyouawake < /dev/null; true'
# Rollback: the steps of the "Rollback" section in docs/getting-started.md, in order.
# shellcheck disable=SC2016  # $(whoami) must expand in the VM, not here
x 'sudo chown -R "$(whoami)" /opt/homebrew'
x "sed -i '' '/brew-wrapper.zsh/d' ~/.zshrc"
x 'sudo sysadminctl -deleteUser homebrew 2>/dev/null'
x 'sudo rm -r /usr/local/share/homebrew-shared-mac'
check "rollback: hidden account is gone" '! dscl . -read /Users/homebrew >/dev/null 2>&1'
check "rollback: the home folder is gone" '! test -e /Users/homebrew'
# shellcheck disable=SC2016  # $(whoami) must expand in the VM, not here
check "rollback: the admin owns the prefix" 'test -z "$(find /opt/homebrew ! -user "$(whoami)" | head -1)"'
check "rollback: no wrapper line or files are left" '! grep -q brew-wrapper ~/.zshrc && ! test -e /usr/local/share/homebrew-shared-mac'
check "rollback: brew install and uninstall work for the admin without sudo" 'zsh -ilc "brew install hello && brew uninstall hello"'
