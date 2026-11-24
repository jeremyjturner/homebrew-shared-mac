#!/bin/bash
# Share one Homebrew installation between several macOS users.
#
# This is the only script you need. It does three things:
#   1. Checks Homebrew, finds the problem, and fixes it (wrong owner, mixed owners).
#   2. Creates the hidden account that owns Homebrew. You choose the name.
#      The script sets a random password that nobody sees (no one logs in with it).
#   3. Writes a report file that you can give to your own AI agent to troubleshoot.
#
# Usage:
#   sudo ./scripts/setup.sh           check, show the plan, ask, then change
#   sudo ./scripts/setup.sh --check   check and write the report; change nothing
#
# Options:
#   --owner NAME       name of the owner account (default: homebrew)
#   --report FILE      where to write the report
#   --yes              do not ask questions (for tests)
set -u -o pipefail

PREFIX=/opt/homebrew
BREW=$PREFIX/bin/brew
OWNER=""
FIRST_UID=600
SHARE_DIR=/usr/local/share/homebrew-shared-mac
HERE=$(cd "$(dirname "$0")" && pwd)
WRAPPER_SRC=$HERE/brew-wrapper.zsh
WRAPPER_LINE="source $SHARE_DIR/brew-wrapper.zsh"
CHECK_ONLY=0
ASSUME_YES=0
REPORT=""

say()  { printf '%s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
ask() {
  [[ $ASSUME_YES -eq 1 ]] && return 0
  local a
  read -r -p "$1 [y/N] " a </dev/tty || return 1
  [[ $a == [yY] || $a == [yY][eE][sS] ]]
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK_ONLY=1 ;;
    --yes) ASSUME_YES=1 ;;
    --owner) shift; OWNER=${1:-} ;;
    --report) shift; REPORT=${1:-} ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
  shift
done

[[ $EUID -eq 0 ]] || die "Run this script with sudo: sudo ./scripts/setup.sh"
[[ $(uname -s) == Darwin ]] || die "This script is for macOS only."

# The person who typed sudo.
REAL_USER=${SUDO_USER:-$(stat -f %Su /dev/console)}
REAL_HOME=$(dscl . -read "/Users/$REAL_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
[[ -n $REAL_HOME && -d $REAL_HOME ]] || die "Cannot find the home folder of '$REAL_USER'."
[[ -n $REPORT ]] || REPORT="$REAL_HOME/shared-brew-report-$(date +%Y%m%d-%H%M%S).txt"

# ---------- helpers for accounts ----------
user_exists() { dscl . -read "/Users/$1" UniqueID >/dev/null 2>&1; }
user_uid()    { dscl . -read "/Users/$1" UniqueID 2>/dev/null | awk '{print $2}'; }
user_shell()  { dscl . -read "/Users/$1" UserShell 2>/dev/null | awk '{print $2}'; }
user_home()   { dscl . -read "/Users/$1" NFSHomeDirectory 2>/dev/null | awk '{print $2}'; }
is_hidden()   { [[ $(dscl . -read "/Users/$1" IsHidden 2>/dev/null | awk '{print $2}') == 1 ]]; }
is_admin()    { dseditgroup -o checkmember -m "$1" admin 2>/dev/null | grep -q '^yes'; }
is_service()  { user_exists "$1" && { is_hidden "$1" || [[ $(user_shell "$1") == /usr/bin/false ]]; }; }
all_accounts(){ dscl . -list /Users UniqueID | awk '$2 >= 500 && $1 !~ /^_/ {print $1}'; }
human_accounts() {
  local u
  for u in $(all_accounts); do is_service "$u" || echo "$u"; done
}
next_free_uid() {
  local n=$FIRST_UID
  while dscl . -list /Users UniqueID | awk '{print $2}' | grep -qx "$n"; do n=$((n + 1)); done
  echo "$n"
}
brew_in_shell_files() {   # does this home folder set up brew?
  local f
  for f in .zprofile .zshrc .bash_profile .profile; do
    grep -qs 'brew' "$1/$f" && return 0
  done
  return 1
}

# ---------- 1. check ----------
FINDINGS=""
add_finding() { FINDINGS="${FINDINGS}  - $*"$'\n'; }

diagnose() {
  local u home n
  MACOS=$(sw_vers -productVersion 2>/dev/null)
  ARCH=$(uname -m)
  PREFIX_PRESENT=0; OWNER_NOW=""; GROUP_NOW=""; BREW_VERSION="not found"
  INSTALL_METHOD="not installed"; N_BAD=0; OWNER_HISTOGRAM=""; N_GROUP_WRITABLE=0
  STATE=none; BREW_RUNNING=0; CLAUDE_RUNNING=0
  N_HUMANS=0; N_USING=0

  if [[ -d $PREFIX ]]; then
    PREFIX_PRESENT=1
    OWNER_NOW=$(stat -f %Su "$PREFIX")
    GROUP_NOW=$(stat -f %Sg "$PREFIX")
    BREW_VERSION=$(sudo -u "$REAL_USER" "$BREW" --version 2>/dev/null | head -1)
    [[ -n $BREW_VERSION ]] || BREW_VERSION="brew does not run"
    if pkgutil --pkgs 2>/dev/null | grep -qi homebrew; then
      INSTALL_METHOD="installer package (.pkg)"
    elif [[ -d $PREFIX/.git ]]; then
      INSTALL_METHOD="install script (git checkout)"
    else
      INSTALL_METHOD="unknown"
    fi
    N_BAD=$(find "$PREFIX" ! -user "$OWNER_NOW" 2>/dev/null | wc -l | tr -d ' ')
    OWNER_HISTOGRAM=$(find "$PREFIX" -print0 2>/dev/null | xargs -0 stat -f '%Su' 2>/dev/null | sort | uniq -c | sort -rn)
    N_GROUP_WRITABLE=$(find "$PREFIX" -perm -g+w 2>/dev/null | wc -l | tr -d ' ')
  fi

  pgrep -x brew >/dev/null 2>&1 && BREW_RUNNING=1
  pgrep -fq 'Homebrew/brew.rb|Library/Homebrew/brew.sh' 2>/dev/null && BREW_RUNNING=1
  pgrep -x claude >/dev/null 2>&1 && CLAUDE_RUNNING=1

  for u in $(human_accounts); do
    N_HUMANS=$((N_HUMANS + 1))
    home=$(user_home "$u")
    if [[ -d $home ]] && { brew_in_shell_files "$home" || [[ -d $home/Library/Caches/Homebrew ]]; }; then
      N_USING=$((N_USING + 1))
    fi
  done

  # Decide the state.
  if [[ $PREFIX_PRESENT -eq 0 ]]; then
    STATE=none
    add_finding "Homebrew is not installed in $PREFIX."
  elif is_service "$OWNER_NOW"; then
    if [[ $N_BAD -eq 0 && $N_GROUP_WRITABLE -eq 0 ]]; then
      STATE=ready
      add_finding "Homebrew is already set up: the hidden account '$OWNER_NOW' owns every file."
    else
      STATE=drift
      add_finding "The hidden account '$OWNER_NOW' owns $PREFIX, but $N_BAD file(s) have another owner and $N_GROUP_WRITABLE are group-writable."
    fi
  else
    STATE=problem
    add_finding "A person's account ('$OWNER_NOW') owns $PREFIX. Other users get 'not writable' errors."
    [[ $N_BAD -gt 0 ]] && add_finding "$N_BAD file(s) have a different owner than '$OWNER_NOW' (mixed owners)."
  fi
  [[ $N_USING -gt 1 && $STATE == problem ]] && add_finding "$N_USING people use Homebrew on this Mac, so they will collide."
  [[ $BREW_RUNNING -eq 1 ]] && add_finding "A brew command is running now. Close it before you make changes."
  [[ $CLAUDE_RUNNING -eq 1 ]] && add_finding "A Claude Code session is running. Close it before you make changes."
  [[ $ARCH == arm64 ]] || add_finding "This is not an Apple silicon Mac ($ARCH). This project supports $PREFIX only."
}

write_report() {   # $1 = title of this snapshot
  {
    echo "=== $1 ==="
    echo "date: $(date '+%Y-%m-%d %H:%M:%S %z')"
    echo "macOS: $MACOS ($ARCH)"
    echo "script run by: $REAL_USER"
    echo
    echo "-- Homebrew --"
    echo "prefix present: $PREFIX_PRESENT ($PREFIX)"
    echo "version: $BREW_VERSION"
    echo "installed with: $INSTALL_METHOD"
    echo "pkg user file /var/tmp/.homebrew_pkg_user: $([[ -e /var/tmp/.homebrew_pkg_user.plist ]] && echo yes || echo no)"
    echo "prefix owner:group: $OWNER_NOW:$GROUP_NOW"
    echo "prefix mode: $(stat -f %Sp "$PREFIX" 2>/dev/null)"
    echo "files not owned by the prefix owner: $N_BAD"
    echo "group-writable files: $N_GROUP_WRITABLE"
    echo "file owners (count, name):"
    # shellcheck disable=SC2001  # indent every line; ${var//} cannot do that
    echo "$OWNER_HISTOGRAM" | sed 's/^/  /'
    echo "other brew locations:"
    local p
    for p in /usr/local/Homebrew /usr/local/bin/brew /home/linuxbrew; do
      [[ -e $p ]] && echo "  found: $p"
    done
    echo "brew command running: $BREW_RUNNING"
    echo "Claude Code running: $CLAUDE_RUNNING"
    echo "sudo rules with NOPASSWD: $(grep -rlE 'NOPASSWD' /etc/sudoers /etc/sudoers.d 2>/dev/null | wc -l | tr -d ' ') file(s)"
    echo "wrapper installed system-wide: $([[ -f $SHARE_DIR/brew-wrapper.zsh ]] && echo yes || echo no)"
    echo
    echo "-- Accounts (UID 500 and higher) --"
    printf '%-20s %-6s %-6s %-8s %-14s %s\n' account uid admin hidden brew-in-shell wrapper-in-zshrc
    local u home
    for u in $(all_accounts); do
      home=$(user_home "$u")
      printf '%-20s %-6s %-6s %-8s %-14s %s\n' "$u" "$(user_uid "$u")" \
        "$(is_admin "$u" && echo yes || echo no)" \
        "$(is_hidden "$u" && echo yes || echo no)" \
        "$([[ -d $home ]] && brew_in_shell_files "$home" && echo yes || echo no)" \
        "$(grep -qs 'homebrew-shared-mac/brew-wrapper.zsh' "$home/.zshrc" && echo yes || echo no)"
    done
    echo
    echo "-- Result --"
    echo "state: $STATE   (none | problem | drift | ready)"
    printf '%s' "$FINDINGS"
    echo
  } >>"$REPORT"
}

print_summary() {
  say ""
  say "What I found"
  say "  macOS $MACOS ($ARCH)"
  if [[ $PREFIX_PRESENT -eq 1 ]]; then
    say "  Homebrew: $BREW_VERSION"
    say "  Installed with: $INSTALL_METHOD"
    say "  Owner of $PREFIX: $OWNER_NOW"
    say "  Files with a different owner: $N_BAD"
  fi
  say "  People accounts on this Mac: $N_HUMANS ($N_USING use Homebrew)"
  say ""
  say "Result"
  printf '%s' "$FINDINGS"
  say ""
}

# ---------- 2. set up ----------
choose_owner() {
  if [[ $STATE == ready || $STATE == drift ]]; then
    OWNER=$OWNER_NOW      # keep the account that already owns Homebrew
    CREATE_OWNER=0
    return
  fi
  if [[ -z $OWNER ]]; then
    if [[ $ASSUME_YES -eq 1 ]]; then
      OWNER=homebrew
    else
      read -r -p "Name for the hidden Homebrew account [homebrew]: " OWNER </dev/tty
      OWNER=${OWNER:-homebrew}
    fi
  fi
  [[ $OWNER =~ ^[a-z_][a-z0-9_-]{0,30}$ ]] || die "Use 1 to 31 characters: lowercase letters, digits, '-' or '_'. Start with a letter."
  if user_exists "$OWNER"; then
    is_service "$OWNER" || die "'$OWNER' is a person's account. Choose another name."
    say "The hidden account '$OWNER' already exists. I will use it."
    CREATE_OWNER=0
  fi
}

# The owner account never logs in. Nobody needs its password, so use a random one.
# An administrator can set a new one later: sudo dscl . -passwd /Users/NAME NEWPASSWORD
make_password() {
  PW=$(openssl rand -base64 36 | tr -dc 'A-Za-z0-9' | cut -c1-24)
  [[ ${#PW} -eq 24 ]] || die "Could not make a random password."
}

print_plan() {
  say "Plan"
  if [[ $CREATE_OWNER -eq 1 ]]; then
    say "  1. Create the administrator account '$OWNER' (UID $(next_free_uid)) with a random password."
    say "  2. Hide it and set its shell to /usr/bin/false (nobody can log in with it)."
  else
    say "  1. Use the existing hidden account '$OWNER'."
  fi
  say "  3. Run: chown -R $OWNER:admin $PREFIX ; chmod -R g-w,o-w $PREFIX"
  say "  4. Put the brew wrapper in $SHARE_DIR and add it to $REAL_USER's ~/.zshrc."
  say "  5. Check the result."
  say "Undo: sudo chown -R <your-user> $PREFIX"
  say ""
}

apply() {
  local uid
  if [[ $CREATE_OWNER -eq 1 ]]; then
    uid=$(next_free_uid)
    # sysadminctl needs the password as an argument. Other admins could see it
    # in the process list for a moment. They can already become root.
    local out
    say "Creating the hidden account '$OWNER'..."
    out=$(sysadminctl -addUser "$OWNER" -fullName "Homebrew Owner" -UID "$uid" -admin -password "$PW" 2>&1) \
      || { printf '%s\n' "$out" >&2; die "Could not create '$OWNER'. Nothing else was changed."; }
    dscl . create "/Users/$OWNER" IsHidden 1 || die "Could not hide '$OWNER'."
    dscl . create "/Users/$OWNER" UserShell /usr/bin/false || die "Could not set the shell."
    dscl . -authonly "$OWNER" "$PW" >/dev/null 2>&1 || warn "The new account did not pass a test login."
    unset PW
    say "Created the hidden account '$OWNER'."
  fi
  chown -R "$OWNER:admin" "$PREFIX" || die "chown failed. Run the script again."
  chmod -R g-w,o-w "$PREFIX" || die "chmod failed. Run the script again."
  say "Changed the owner of $PREFIX to '$OWNER'."
  install_wrapper
}

install_wrapper() {
  install -d -m 755 "$SHARE_DIR"
  install -m 644 "$WRAPPER_SRC" "$SHARE_DIR/brew-wrapper.zsh"
  if ! grep -qsF "$WRAPPER_LINE" "$REAL_HOME/.zshrc"; then
    if ask "Add the brew wrapper to $REAL_HOME/.zshrc?"; then
      sudo -u "$REAL_USER" sh -c "echo '$WRAPPER_LINE' >> '$REAL_HOME/.zshrc'"
      say "Added the wrapper to ~/.zshrc."
    fi
  fi
}

final_check() {
  local fail=0 bad
  bad=$(find "$PREFIX" ! -user "$OWNER" 2>/dev/null | head -3)
  if [[ -z $bad ]]; then say "PASS  '$OWNER' owns every file in $PREFIX"
  else say "FAIL  files with another owner:"; say "$bad"; fail=1; fi
  if sudo -u "$REAL_USER" "$BREW" --version >/dev/null 2>&1; then say "PASS  brew --version works for $REAL_USER"
  else say "FAIL  brew --version does not work for $REAL_USER"; fail=1; fi
  if [[ -f $SHARE_DIR/brew-wrapper.zsh ]]; then say "PASS  wrapper is in $SHARE_DIR"
  else say "FAIL  wrapper is missing"; fail=1; fi
  # A new Terminal window must load the wrapper. Test it the same way: a fresh login shell.
  if grep -qsF "$WRAPPER_LINE" "$REAL_HOME/.zshrc"; then
    if sudo -u "$REAL_USER" -H /bin/zsh -ilc 'type brew' 2>/dev/null | grep -q 'shell function'; then
      say "PASS  a new Terminal window loads the wrapper"
    else
      say "FAIL  a new Terminal window does not load the wrapper"; fail=1
    fi
  else
    say "NOTE  the wrapper is not in $REAL_HOME/.zshrc, so plain brew commands will fail."
  fi
  return $fail
}

# ---------- run ----------
: >"$REPORT"
chown "$REAL_USER" "$REPORT"; chmod 600 "$REPORT"

say "Checking this Mac. This can take a minute."
CREATE_OWNER=1
diagnose
write_report "BEFORE"
print_summary

if [[ $CHECK_ONLY -eq 1 || $STATE == none ]]; then
  [[ $STATE == none ]] && say "Install Homebrew first (https://brew.sh), then run this script again."
  say "Nothing was changed."
  say "Report: $REPORT"
  say "The report lists the account names on this Mac. Read it before you share it."
  exit 0
fi

if [[ $STATE == ready ]]; then
  say "Nothing to fix."
  OWNER=$OWNER_NOW
  install_wrapper
  final_check
  say "Report: $REPORT"
  exit 0
fi

[[ $ARCH == arm64 ]] || die "Apple silicon only."
if [[ $BREW_RUNNING -eq 1 ]]; then die "Close all brew commands, then run this script again."; fi
if [[ $CLAUDE_RUNNING -eq 1 ]]; then ask "A Claude Code session is open. Continue anyway?" || die "Close Claude Code, then run this script again."; fi

choose_owner
print_plan
ask "Make these changes now?" || { say "Nothing was changed."; say "Report: $REPORT"; exit 0; }
PW=""
[[ $CREATE_OWNER -eq 1 ]] && make_password
apply

FINDINGS=""
diagnose
write_report "AFTER"
final_check; rc=$?

say ""
say "Next"
say "  1. Close this Terminal window and open a new one."
say "     Only a new window loads the wrapper. (Or run: source ~/.zshrc)"
say "  2. Test it (this asks for YOUR password): brew update"
say "     If brew says 'not writable' and shows 'sudo chown', do not run that command."
say "     It means this window does not have the wrapper yet. Open a new window."
say "  3. For each other person: log in as that person and run:"
say "       echo '$WRAPPER_LINE' >> ~/.zshrc"
say ""
say "Report for your AI agent: $REPORT"
say "The report lists the account names on this Mac. Read it before you share it."
exit $rc
