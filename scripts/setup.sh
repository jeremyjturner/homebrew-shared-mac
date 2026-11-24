#!/bin/bash
# Create a hidden Homebrew owner account and hand /opt/homebrew to it.
# Run as an admin user. Close all brew and Claude Code sessions first.
# Usage: sudo ./scripts/setup.sh            (prints plan, changes nothing)
#        sudo ./scripts/setup.sh --apply    (makes the changes)
set -euo pipefail

OWNER=homebrew
OWNER_UID=600
PREFIX=/opt/homebrew

[[ $EUID -eq 0 ]] || { echo "Run with sudo." >&2; exit 1; }
[[ -d $PREFIX ]] || { echo "$PREFIX not found (Apple Silicon only)." >&2; exit 1; }
if id "$OWNER" >/dev/null 2>&1; then echo "User $OWNER already exists." >&2; exit 1; fi
if dscl . -list /Users UniqueID | awk '{print $2}' | grep -qx "$OWNER_UID"; then
  echo "UID $OWNER_UID is already in use; edit OWNER_UID." >&2; exit 1
fi

if [[ ${1:-} != --apply ]]; then
  cat <<PLAN
Plan (re-run with --apply):
  1. create admin user '$OWNER' (UID $OWNER_UID), prompting for a password
  2. hide it and set its shell to /usr/bin/false
  3. chown -R $OWNER:admin $PREFIX ; chmod -R g-w,o-w $PREFIX
Rollback: sudo chown -R <user> $PREFIX
PLAN
  exit 0
fi

read -r -s -p "Password for new '$OWNER' account: " PW; echo
sysadminctl -addUser "$OWNER" -fullName Homebrew -UID "$OWNER_UID" -admin -password "$PW"
unset PW
dscl . create "/Users/$OWNER" IsHidden 1
dscl . create "/Users/$OWNER" UserShell /usr/bin/false
chown -R "$OWNER:admin" "$PREFIX"
chmod -R g-w,o-w "$PREFIX"
echo "Done. Add scripts/brew-wrapper.zsh to each user's ~/.zshrc."
