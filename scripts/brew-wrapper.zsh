# Source from each human user's ~/.zshrc.
# Only these run directly as a non-owner; everything else needs the owner
# account (tested: info/search/config/outdated/deps/uses/leaves/desc write
# lock files into the prefix and fail for non-owners).
# The owner account cannot enter your home folder. The owner-run commands start in
# /var/empty, or brew stops with "The current working directory must exist to run brew".
# Do not use /tmp: any user can write there, and brew runs a Brewfile it finds in the
# current folder as the owner.
#
# `brew update-all` is not a Homebrew command. It runs update, upgrade (formulae and
# casks), autoremove and cleanup. It asks for your password once. Each `brew as-brew-user`
# call asks again, because Homebrew resets the sudo timestamp on every user switch.
# So the wrapper switches to the owner once, and the owner runs all four steps.
# Options go to the upgrade step: `brew update-all --yes` skips Homebrew's "proceed?" question.
# This adds no sudoers rule: the password prompt stays the only boundary.
brew() {
  case "$1" in
    --prefix|--cellar|--repository|--version|list|ls|home)
      command brew "$@" ;;
    update-all)
      shift
      local prefix owner
      prefix="$(command brew --prefix)" || return
      owner="$(/usr/bin/stat -f %Su "$prefix")" || return
      (cd /var/empty && /usr/bin/sudo -H -u "$owner" /usr/bin/env HOMEBREW_SUDO_USER="$(/usr/bin/id -un)" \
        HOMEBREW_NO_ENV_HINTS=1 /bin/bash -c '
          brew_bin=$1; shift
          for step in update upgrade autoremove cleanup; do
            echo "==> brew $step"
            if [ "$step" = upgrade ]; then "$brew_bin" as-brew-user upgrade "$@" || exit
            else "$brew_bin" as-brew-user "$step" || exit; fi
          done' brew-update-all "$prefix/bin/brew" "$@") ;;
    *)
      (cd /var/empty && command brew as-brew-user "$@") ;;
  esac
}
