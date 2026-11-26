#!/bin/bash
# Share one Homebrew installation between several macOS users.
#
# This is the only script you need. It does these things:
#   1. Checks Homebrew, finds the problem, and fixes it (wrong owner, mixed owners).
#   2. Creates the hidden account that owns Homebrew. You choose the name.
#      The script sets a random password that nobody sees (no one logs in with it).
#   3. Adds the brew wrapper to every account that uses Homebrew.
#   4. Turns off HOMEBREW_CASK_OPTS="--appdir=..." (brew ignores it now) and moves
#      the apps that brew put in a user's ~/Applications to /Applications.
#   5. Writes a report file that you can give to your own AI agent.
# Every change is saved in a backup folder. --rollback undoes all of it.
#
# Usage:
#   sudo ./scripts/setup.sh              check, show the plan, ask, then change
#   sudo ./scripts/setup.sh --check      check and write the report; change nothing
#   sudo ./scripts/setup.sh --rollback   undo the last run of this script
#
# Options:
#   --owner NAME       name of the owner account (default: homebrew)
#   --report FILE      where to write the report
#   --backup DIR       with --rollback: use this backup folder (default: the newest)
#   --yes              do not ask questions (for tests)
set -u -o pipefail

PREFIX=/opt/homebrew
BREW=$PREFIX/bin/brew
# Hide brew's sudo-domain warning and hints: they are harmless but look like errors.
export HOMEBREW_SERVICES_NO_DOMAIN_WARNING=1 HOMEBREW_NO_ENV_HINTS=1
OWNER=""
FIRST_UID=600
SHARE_DIR=/usr/local/share/homebrew-shared-mac
BACKUP_ROOT=$SHARE_DIR/backups
BACKUP=""
HERE=$(cd "$(dirname "$0")" && pwd)
WRAPPER_SRC=$HERE/brew-wrapper.zsh
WRAPPER_LINE="source $SHARE_DIR/brew-wrapper.zsh"
DISABLED_MARK="# homebrew-shared-mac disabled: "
CHECK_ONLY=0
ASSUME_YES=0
ROLLBACK=0
ROLLBACK_DIR=""
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
    --rollback) ROLLBACK=1 ;;
    --backup) shift; ROLLBACK_DIR=${1:-} ;;
    --owner) shift; OWNER=${1:-} ;;
    --report) shift; REPORT=${1:-} ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
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

# Does this home folder set HOMEBREW_CASK_OPTS with --appdir? The brew wrapper runs
# brew as the owner account with a clean environment, so this setting is ignored.
# Prints "file: line" for each match.
appdir_setting() {
  local f
  for f in .zshrc .zprofile .zshenv .bash_profile .profile; do
    grep -sE '^[[:space:]]*(export[[:space:]]+)?HOMEBREW_CASK_OPTS=.*appdir' "$1/$f" 2>/dev/null \
      | sed "s|^|$f: |"
  done
}

# Casks that brew installed into a user's ~/Applications. Homebrew keeps a symlink in
# the Caskroom that points to each installed app. Prints: user<TAB>cask<TAB>app path.
find_appdir_casks() {
  local u home l
  [[ -d $PREFIX/Caskroom ]] || return 0
  for u in $(all_accounts); do
    home=$(user_home "$u")
    [[ -d $home/Applications ]] || continue
    find "$PREFIX/Caskroom" -mindepth 3 -maxdepth 3 -type l -lname "$home/Applications/*" 2>/dev/null \
      | while read -r l; do
          printf '%s\t%s\t%s\n' "$u" "$(echo "${l#"$PREFIX/Caskroom/"}" | cut -d/ -f1)" "$(readlink "$l")"
        done
  done
}

# Casks that brew installed into /Applications, but another account owns the app (a person
# or root). The owner account cannot write there, so brew asks for the owner's sudo
# password on update or remove, and nobody knows it. Prints: owner<TAB>cask<TAB>app path.
#
# Some apps have no symlink: the Caskroom holds a real copy of the app (brew --adopt, or an
# old failed upgrade). Then "brew upgrade" stops with "It seems there is already an App at".
# Those apps are always listed, whoever owns them. The 4th field is the copy in the Caskroom
# ("-" when there is a normal symlink).
find_foreign_apps() {
  local l app o
  [[ -d $PREFIX/Caskroom ]] || return 0
  find "$PREFIX/Caskroom" -mindepth 3 -maxdepth 3 -type l -lname '/Applications/*' 2>/dev/null \
    | while read -r l; do
        app=$(readlink "$l"); [[ -d $app ]] || continue
        o=$(stat -f %Su "$app" 2>/dev/null)
        [[ -n $o ]] || continue
        if [[ -n $OWNER_NOW ]] && is_service "$OWNER_NOW" && [[ $o == "$OWNER_NOW" ]]; then continue; fi
        printf '%s\t%s\t%s\t-\n' "$o" "$(echo "${l#"$PREFIX/Caskroom/"}" | cut -d/ -f1)" "$app"
      done
  find "$PREFIX/Caskroom" -mindepth 3 -maxdepth 3 -type d -name '*.app' 2>/dev/null \
    | while read -r l; do
        app=/Applications/$(basename "$l"); [[ -d $app && ! -L $app ]] || continue
        o=$(stat -f %Su "$app" 2>/dev/null)
        [[ -n $o ]] || continue
        printf '%s\t%s\t%s\t%s\n' "$o" "$(echo "${l#"$PREFIX/Caskroom/"}" | cut -d/ -f1)" "$app" "$l"
      done
}

# ---------- backup and rollback ----------
# The manifest has one line per change: kind, then up to four values, separated by tabs.
# Rollback reads it from the last line to the first.
record() { printf '%s\t%s\t%s\t%s\n' "$1" "${2:--}" "${3:--}" "${4:--}" >>"$BACKUP/manifest"; }

start_backup() {
  [[ -z $BACKUP ]] || return 0
  BACKUP=$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)
  install -d -m 755 "$SHARE_DIR"
  install -d -m 700 "$BACKUP_ROOT" "$BACKUP" "$BACKUP/files" "$BACKUP/apps"
  : >"$BACKUP/manifest"
}

backup_file() {   # copy a file into the backup folder before it is changed
  cp -p "$1" "$BACKUP/files/$(printf '%s' "$1" | tr '/' '_')"
}

edit_file() {     # $1 = file, $2 = sed -E expression. Keeps the owner and mode of the file.
  # Read and write as the account that owns the file, never as root. The file is in a
  # folder that the account controls. A link there must not lead root to another file.
  local tmp who
  who=$(stat -f %Su "$1") || return 1
  [[ $who == root && -L $1 ]] && return 1
  tmp=$(mktemp) || return 1
  # The redirects open only the private temp file, as root. The user's file is opened by sudo -u.
  # shellcheck disable=SC2024
  sudo -u "$who" sed -E "$2" "$1" >"$tmp" && sudo -u "$who" tee "$1" <"$tmp" >/dev/null
  rm -f "$tmp"
}

do_rollback() {
  local dir=$ROLLBACK_DIR kind a b c u
  if [[ -z $dir ]]; then
    # The newest backup that has changes in it. A run that changed nothing leaves an empty one.
    local d
    for d in $(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name '2*' 2>/dev/null | sort); do
      case $d in *.rolled-back) continue ;; esac
      [[ -s $d/manifest ]] && dir=$d
    done
  fi
  [[ -n $dir && -s $dir/manifest ]] || die "No backup found in $BACKUP_ROOT. There is nothing to undo."
  case $dir in *.rolled-back) die "This backup was already used: $dir" ;; esac
  pgrep -x brew >/dev/null 2>&1 && die "A brew command is running. Close it, then run the rollback again."

  say "Rollback from $dir"
  say "This will undo, in this order:"
  tail -r "$dir/manifest" | while IFS=$'\t' read -r kind a b c; do
    case $kind in
      app_chowned)      say "  - give $a back its old owner '$b'" ;;
      app_moved)        say "  - put $c back (the cask '$b' returns to its old folder)" ;;
      caskroom_link)    say "  - put the old copy of '$b' back in the Caskroom" ;;
      appdir_disabled)  say "  - turn the HOMEBREW_CASK_OPTS line back on in $a" ;;
      wrapper_added)    say "  - remove the brew wrapper line from $a" ;;
      owner_before)     say "  - give $PREFIX back to '$a'" ;;
      account_created)  say "  - delete the hidden account '$a' and its home folder" ;;
    esac
  done
  say "Brew will not manage the apps that go back to ~/Applications until you reinstall them."
  say ""
  ask "Undo these changes now?" || { say "Nothing was changed."; exit 0; }

  tail -r "$dir/manifest" | while IFS=$'\t' read -r kind a b c; do
    case $kind in
      app_chowned)   # a=app path b=old owner c=old group
        chown -R "$b:$c" "$a" && say "Gave $a back to '$b'." ;;
      caskroom_link)   # a=Caskroom path (now a link) b=cask c=saved copy
        if [[ -L $a && -d $c ]]; then rm "$a" && mv "$c" "$a" && say "Put back the old copy of '$b' in the Caskroom."
        else warn "Could not put back $a."; fi ;;
      app_moved)   # a=user b=cask c=original path; the saved app is in the backup folder
        "$BREW" as-brew-user uninstall --cask --force "$b" </dev/null >/dev/null 2>&1 \
          || warn "Could not remove the new copy of '$b'. Check /Applications."
        if [[ -e $c ]]; then
          warn "$c already exists. The old app stays in $dir/apps."
        else
          mv "$dir/apps/$a/$b/$(basename "$c")" "$c" && say "Put back $c"
        fi ;;
      appdir_disabled)
        edit_file "$a" "s|^${DISABLED_MARK}||" && say "Turned the setting back on in $a" ;;
      wrapper_added)
        edit_file "$a" '\|homebrew-shared-mac/brew-wrapper.zsh|d' && say "Removed the wrapper line from $a" ;;
      owner_before)
        chown -R "$a:$b" "$PREFIX" && chmod -R g+w "$PREFIX" && say "Gave $PREFIX back to '$a'." ;;
      account_created)
        sysadminctl -deleteUser "$a" >/dev/null 2>&1
        if user_exists "$a"; then warn "Could not delete the account '$a'."; else say "Deleted the hidden account '$a'."; fi ;;
    esac
  done

  # Remove the wrapper file only when no account still uses it.
  local still=0
  for u in $(all_accounts); do
    grep -qs 'homebrew-shared-mac/brew-wrapper.zsh' "$(user_home "$u")/.zshrc" && still=1
  done
  [[ $still -eq 0 ]] && rm -f "$SHARE_DIR/brew-wrapper.zsh"
  mv "$dir" "$dir.rolled-back"
  say ""
  say "Done. Open a new Terminal window in each account."
  say "The backup is now $dir.rolled-back (delete it when you do not need it)."
}

# ---------- 1. check ----------
FINDINGS=""
add_finding() { FINDINGS="${FINDINGS}  - $*"$'\n'; }

diagnose() {
  local u home n
  MACOS=$(sw_vers -productVersion 2>/dev/null)
  ARCH=$(uname -m)
  PREFIX_PRESENT=0; OWNER_NOW=""; GROUP_NOW=""; BREW_VERSION="not found"; FOREIGN_APPS=""
  INSTALL_METHOD="not installed"; N_BAD=0; OWNER_HISTOGRAM=""; N_GROUP_WRITABLE=0
  STATE=none; BREW_RUNNING=0; CLAUDE_RUNNING=0
  N_HUMANS=0; N_USING=0; APPDIR_USERS=""; APPDIR_CASKS=""; WRAPPER_USERS=$REAL_USER

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
    APPDIR_CASKS=$(find_appdir_casks | sort -u)
    FOREIGN_APPS=$(find_foreign_apps | sort -u)
  fi

  pgrep -x brew >/dev/null 2>&1 && BREW_RUNNING=1
  pgrep -fq 'Homebrew/brew.rb|Library/Homebrew/brew.sh' 2>/dev/null && BREW_RUNNING=1
  pgrep -x claude >/dev/null 2>&1 && CLAUDE_RUNNING=1
  CLAUDE_USERS=$(ps -axo user=,comm= 2>/dev/null | awk '$2 ~ /(^|\/)claude$/ {print $1}' | sort -u | tr '\n' ' ')

  for u in $(human_accounts); do
    N_HUMANS=$((N_HUMANS + 1))
    home=$(user_home "$u")
    if [[ -d $home ]] && { brew_in_shell_files "$home" || [[ -d $home/Library/Caches/Homebrew ]]; }; then
      N_USING=$((N_USING + 1))
      add_wrapper_user "$u"
    fi
    if [[ -d $home && -n $(appdir_setting "$home") ]]; then
      APPDIR_USERS="${APPDIR_USERS}${APPDIR_USERS:+ }$u"
      add_wrapper_user "$u"
    fi
  done
  while IFS=$'\t' read -r u _; do
    [[ -n $u ]] && add_wrapper_user "$u"
  done <<<"$APPDIR_CASKS"
  MISSING_WRAPPER=""
  for u in $WRAPPER_USERS; do
    grep -qsF "$WRAPPER_LINE" "$(user_home "$u")/.zshrc" || MISSING_WRAPPER="${MISSING_WRAPPER}${MISSING_WRAPPER:+ }$u"
  done
  # An installed wrapper that differs from this repo's copy is old: it may have a known bug.
  WRAPPER_STALE=0
  [[ -f $SHARE_DIR/brew-wrapper.zsh ]] && ! cmp -s "$WRAPPER_SRC" "$SHARE_DIR/brew-wrapper.zsh" && WRAPPER_STALE=1

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
  [[ -n $APPDIR_USERS ]] && add_finding "HOMEBREW_CASK_OPTS sets --appdir for: $APPDIR_USERS. Brew ignores it after the fix. The script turns it off."
  if [[ -n $APPDIR_CASKS ]]; then
    n_apps=$(printf '%s\n' "$APPDIR_CASKS" | wc -l | tr -d ' ')
    if [[ $n_apps -eq 1 ]]; then app_word="cask app is"; else app_word="cask apps are"; fi
    add_finding "$n_apps $app_word in a user's ~/Applications: $(printf '%s\n' "$APPDIR_CASKS" | cut -f2 | sort -u | tr '\n' ' ')"
    add_finding "The owner account cannot update or remove them there. The script moves them to /Applications."
  fi
  if [[ -n $FOREIGN_APPS ]]; then
    add_finding "Brew apps in /Applications that brew cannot update (another account owns them, or brew keeps a second copy): $(printf '%s\n' "$FOREIGN_APPS" | cut -f2 | sort -u | tr '\n' ' ')"
    add_finding "Without a fix, brew asks for a password that nobody knows when it updates them. The script gives them to '${OWNER_NOW:-the hidden account}'."
  fi
  [[ -n $MISSING_WRAPPER ]] && add_finding "The brew wrapper is missing for: $MISSING_WRAPPER."
  [[ $WRAPPER_STALE -eq 1 ]] && add_finding "The installed brew wrapper is out of date. An old wrapper can fail with 'The current working directory must exist to run brew'. The script replaces it."
  [[ $BREW_RUNNING -eq 1 ]] && add_finding "A brew command is running now. Close it before you make changes."
  [[ $CLAUDE_RUNNING -eq 1 ]] && add_finding "A Claude Code session is running${CLAUDE_USERS:+ (account: ${CLAUDE_USERS% })}. Close it before you make changes."
  while IFS=$'\t' read -r _ _ app; do
    [[ -n $app ]] && pgrep -fq "$app/Contents/MacOS/" \
      && add_finding "$(basename "$app") is open now (account: $(ps -axo user=,command= | awk -v a="$app/Contents/MacOS/" 'index($0,a){print $1; exit}')). Quit it before you make changes."
  done <<<"$APPDIR_CASKS"
  [[ $ARCH == arm64 ]] || add_finding "This is not an Apple silicon Mac ($ARCH). This project supports $PREFIX only."
}

add_wrapper_user() {   # add $1 to WRAPPER_USERS once
  case " $WRAPPER_USERS " in *" $1 "*) ;; *) WRAPPER_USERS="$WRAPPER_USERS $1" ;; esac
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
    echo "backup folder: ${BACKUP:-none}"
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
    echo "-- HOMEBREW_CASK_OPTS with --appdir (brew ignores it) --"
    for u in $(all_accounts); do
      home=$(user_home "$u")
      [[ -d $home ]] && appdir_setting "$home" | sed "s/^/  $u  /"
      [[ -d $home ]] && grep -sE "^${DISABLED_MARK}" "$home/.zshrc" | sed "s/^/  $u  (turned off) /"
    done
    echo "cask apps still in a user's ~/Applications (cask, app):"
    printf '%s\n' "$APPDIR_CASKS" | awk -F'\t' 'NF {print "  " $1 "  " $2 "  " $3}'
    echo "other apps in ~/Applications (not managed by brew):"
    for u in $(all_accounts); do
      home=$(user_home "$u")
      [[ -d $home/Applications ]] && find "$home/Applications" -maxdepth 1 -name '*.app' 2>/dev/null | sed 's/^/  /'
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
  local n=0 u
  say "Plan"
  if [[ $CREATE_OWNER -eq 1 ]]; then
    n=$((n + 1)); say "  $n. Create the administrator account '$OWNER' (UID $(next_free_uid)) with a random password."
    n=$((n + 1)); say "  $n. Hide it and set its shell to /usr/bin/false (nobody can log in with it)."
  else
    n=$((n + 1)); say "  $n. Use the existing hidden account '$OWNER'."
  fi
  if [[ $STATE != ready ]]; then
    n=$((n + 1)); say "  $n. Run: chown -R $OWNER:admin $PREFIX ; chmod -R g-w,o-w $PREFIX"
  fi
  if [[ -n $MISSING_WRAPPER ]]; then
    n=$((n + 1)); say "  $n. Put the brew wrapper in $SHARE_DIR and add it to ~/.zshrc of: $MISSING_WRAPPER"
  fi
  if [[ $WRAPPER_STALE -eq 1 ]]; then
    n=$((n + 1)); say "  $n. Replace the old brew wrapper in $SHARE_DIR with the current one."
  fi
  if [[ -n $APPDIR_USERS ]]; then
    n=$((n + 1)); say "  $n. Turn off the HOMEBREW_CASK_OPTS --appdir line (put '#' in front) for: $APPDIR_USERS"
  fi
  if [[ -n $APPDIR_CASKS ]]; then
    n=$((n + 1)); say "  $n. Move these apps out of ~/Applications, then reinstall them with brew into /Applications:"
    while IFS=$'\t' read -r u cask app; do
      [[ -n $app ]] && say "       $cask  ($u: $app)"
    done <<<"$APPDIR_CASKS"
    say "     The old apps are kept in the backup folder. Apps that brew did not install stay where they are."
  fi
  if [[ -n $FOREIGN_APPS ]]; then
    n=$((n + 1)); say "  $n. Give these apps in /Applications to '$OWNER', so brew can update them:"
    while IFS=$'\t' read -r u cask app stale; do
      [[ -n $app ]] || continue
      say "       $cask  ($app, now owned by $u)"
      [[ ${stale:--} != "-" ]] && say "         Brew also keeps a second copy of the app. The script replaces it with a link."
    done <<<"$FOREIGN_APPS"
  fi
  n=$((n + 1)); say "  $n. Check the result."
  say "Every change is saved in $BACKUP_ROOT."
  say "Undo everything: sudo $0 --rollback"
  say ""
}

# Run a command that asks for a password on its terminal, and type $PW there.
# The password goes in the environment of expect, not in any arguments.
run_with_pw() {
  # The expect script comes in on file descriptor 3. The command and its arguments follow
  # the script name, and expect puts them in $argv.
  PW=$PW /usr/bin/expect /dev/fd/3 "$@" 3<<'EOF'
set timeout 60
spawn {*}$argv
expect -re {(?i)password: ?}
send -- "$env(PW)\r"
expect eof
catch wait r
exit [lindex $r 3]
EOF
}

apply() {
  local uid u
  start_backup
  if [[ $CREATE_OWNER -eq 1 ]]; then
    uid=$(next_free_uid)
    # Never put the password in the arguments of a command: any local account can read
    # them in the process list. sysadminctl and dscl ask for it on the terminal when the
    # argument is "-" or missing. run_with_pw types it there.
    local out
    say "Creating the hidden account '$OWNER'..."
    out=$(run_with_pw sysadminctl -addUser "$OWNER" -fullName "Homebrew Owner" -UID "$uid" -admin -password - 2>&1) \
      || { printf '%s\n' "$out" >&2; die "Could not create '$OWNER'. Nothing else was changed."; }
    record account_created "$OWNER"
    dscl . create "/Users/$OWNER" IsHidden 1 || die "Could not hide '$OWNER'."
    dscl . create "/Users/$OWNER" UserShell /usr/bin/false || die "Could not set the shell."
    # Not "dscl -authonly": it needs the password typed at a prompt and then hangs for a minute under expect.
    dscl . -read "/Users/$OWNER" AuthenticationAuthority 2>/dev/null | grep -q ShadowHash \
      || warn "The new account has no password."
    unset PW
    say "Created the hidden account '$OWNER'."
  fi
  if [[ $STATE != ready ]]; then
    record owner_before "$OWNER_NOW" "$GROUP_NOW"
    chown -R "$OWNER:admin" "$PREFIX" || die "chown failed. Run the script again."
    chmod -R g-w,o-w "$PREFIX" || die "chmod failed. Run the script again."
    say "Changed the owner of $PREFIX to '$OWNER'."
  fi
  install_wrapper
  disable_appdir_lines
  [[ -n $APPDIR_CASKS ]] && migrate_apps
  fix_foreign_apps
  return 0
}

install_wrapper_files() {
  install -d -m 755 "$SHARE_DIR"
  install -m 644 "$WRAPPER_SRC" "$SHARE_DIR/brew-wrapper.zsh"
  if [[ ${WRAPPER_STALE:-0} -eq 1 ]]; then say "Replaced the old brew wrapper in $SHARE_DIR."; WRAPPER_STALE=0; fi
}

install_wrapper() {
  local u zr
  install_wrapper_files
  for u in $MISSING_WRAPPER; do
    zr=$(user_home "$u")/.zshrc
    # Write as the account that owns the file, never as root. The file is in a folder
    # that the account controls. A link there must not lead root to another file.
    if [[ -e $zr ]]; then backup_file "$zr"; else sudo -u "$u" touch "$zr" || { warn "Could not create $zr"; continue; }; fi
    # Start on a new line if the file does not end with one.
    [[ -s $zr && -n $(tail -c1 "$zr") ]] && { printf '\n' | sudo -u "$u" tee -a "$zr" >/dev/null; }
    printf '%s\n' "$WRAPPER_LINE" | sudo -u "$u" tee -a "$zr" >/dev/null
    record wrapper_added "$zr"
    say "Added the wrapper to $zr"
  done
}

disable_appdir_lines() {
  local u home f
  for u in $APPDIR_USERS; do
    home=$(user_home "$u")
    for f in $(appdir_setting "$home" | cut -d: -f1 | sort -u); do
      backup_file "$home/$f"
      edit_file "$home/$f" "s|^([[:space:]]*(export[[:space:]]+)?HOMEBREW_CASK_OPTS=.*appdir.*)\$|${DISABLED_MARK}\\1|"
      record appdir_disabled "$home/$f"
      say "Turned off HOMEBREW_CASK_OPTS in $home/$f"
    done
  done
}

# Move each brew app out of ~/Applications, then let brew install it again. The
# owner account installs into /Applications, where it can update and remove the app.
# --appdir is needed: brew remembers the folder of the first install and would reuse it.
migrate_apps() {
  local u cask app saved rule=/etc/sudoers.d/homebrew-shared-mac-temp
  [[ -n $APPDIR_CASKS ]] || return 0
  # Some casks (Steam, for example) ask for sudo when brew removes them. The hidden
  # account has a random password, so nobody can type it. Allow it for this step only.
  printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$OWNER" >"$rule.tmp"
  chmod 440 "$rule.tmp"
  if visudo -cf "$rule.tmp" >/dev/null 2>&1; then mv "$rule.tmp" "$rule"; else rm -f "$rule.tmp"; fi
  trap 'rm -f /etc/sudoers.d/homebrew-shared-mac-temp' EXIT
  while IFS=$'\t' read -r u cask app; do
    [[ -n $app ]] || continue
    saved=$BACKUP/apps/$u/$cask
    install -d -m 700 "$saved"
    mv "$app" "$saved/" || { warn "Could not move $app. Skipped."; continue; }
    say "Reinstalling '$cask' into /Applications..."
    if (cd / && "$BREW" as-brew-user reinstall --cask --appdir=/Applications "$cask" </dev/null); then
      record app_moved "$u" "$cask" "$app"
    else
      warn "Reinstall of '$cask' failed. Putting the old app back."
      mv "$saved/$(basename "$app")" "$app"
      if (cd / && "$BREW" as-brew-user list --cask "$cask" >/dev/null 2>&1 </dev/null); then
        warn "Brew still lists '$cask', but it does not manage the app at $app."
        warn "To fix it later, run: brew reinstall --cask --appdir=/Applications $cask"
      else
        warn "Brew no longer lists '$cask'. The old app is back at $app and brew does not manage it."
        warn "To manage it again, run: brew install --cask --appdir=/Applications $cask"
      fi
    fi
  done <<<"$APPDIR_CASKS"
  rm -f "$rule"
}

fix_foreign_apps() {
  local o cask app g stale saved
  while IFS=$'\t' read -r o cask app stale; do
    [[ -n $app && -d $app ]] || continue
    if [[ $o != "$OWNER" ]]; then
      g=$(stat -f %Sg "$app")
      if chown -R "$OWNER:admin" "$app"; then
        record app_chowned "$app" "$o" "$g"
        say "Gave $app to '$OWNER'."
      else
        warn "Could not change the owner of $app."
      fi
    fi
    # Replace the second copy in the Caskroom with the link that brew normally keeps.
    if [[ ${stale:--} != "-" && -d $stale && ! -L $stale ]]; then
      saved=$BACKUP/apps/caskroom/$cask
      install -d -m 700 "$saved"
      if mv "$stale" "$saved/" && ln -s "$app" "$stale"; then
        chown -h "$OWNER:admin" "$stale"
        record caskroom_link "$stale" "$cask" "$saved/$(basename "$stale")"
        say "Brew now links '$cask' to $app."
      else
        warn "Could not fix the Caskroom copy of '$cask'."
        [[ -e $stale ]] || mv "$saved/$(basename "$stale")" "$stale"
      fi
    fi
  done <<<"$FOREIGN_APPS"
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
  if [[ -z $APPDIR_CASKS && -z $APPDIR_USERS ]]; then say "PASS  no --appdir setting and no brew app in a ~/Applications folder"
  else say "FAIL  an --appdir setting or a brew app is still in a ~/Applications folder"; fail=1; fi
  FOREIGN_APPS=$(find_foreign_apps | sort -u)
  if [[ -z $FOREIGN_APPS ]]; then say "PASS  '$OWNER' owns every brew app in /Applications"
  else say "FAIL  brew cannot update these apps (another account owns them, or a second copy is left): $(printf '%s\n' "$FOREIGN_APPS" | cut -f2 | tr '\n' ' ')"; fail=1; fi
  return $fail
}

# ---------- run ----------
if [[ $ROLLBACK -eq 1 ]]; then
  do_rollback
  exit 0
fi

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

if [[ $STATE == ready && -z $APPDIR_CASKS && -z $APPDIR_USERS && -z $FOREIGN_APPS && -z $MISSING_WRAPPER && $WRAPPER_STALE -eq 0 ]]; then
  say "Nothing to fix."
  OWNER=$OWNER_NOW
  install_wrapper_files
  final_check
  say "Report: $REPORT"
  exit 0
fi

[[ $ARCH == arm64 ]] || die "Apple silicon only."
if [[ $BREW_RUNNING -eq 1 ]]; then die "Close all brew commands, then run this script again."; fi
if [[ $CLAUDE_RUNNING -eq 1 ]]; then ask "A Claude Code session is open. Continue anyway?" || die "Close Claude Code, then run this script again."; fi
# An app that is open must not be moved.
RUNNING_APPS=""
while IFS=$'\t' read -r _ _ app; do
  [[ -n $app ]] && pgrep -fq "$app/Contents/MacOS/" && RUNNING_APPS="${RUNNING_APPS}${RUNNING_APPS:+, }$(basename "$app")"
done <<<"$APPDIR_CASKS"
[[ -z $RUNNING_APPS ]] || die "Quit these apps first, then run this script again: $RUNNING_APPS"

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
say "  3. Tell the other people to open a new Terminal window too."
say "     The script already added the wrapper to their ~/.zshrc."
if [[ -s $BACKUP/manifest ]] && grep -q '^app_moved' "$BACKUP/manifest"; then
  say "  4. A moved app in the Dock now shows a question mark."
  say "     Drag the icon out of the Dock. Then open the app from /Applications"
  say "     and choose Options > Keep in Dock. Do this in each account."
  say "  5. Old copies of the moved apps are in $BACKUP/apps."
  say "     Delete that folder when the new apps work."
fi
say ""
say "Undo all of it: sudo $0 --rollback"
say "Report for your AI agent: $REPORT"
say "The report lists the account names on this Mac. Read it before you share it."
exit $rc
