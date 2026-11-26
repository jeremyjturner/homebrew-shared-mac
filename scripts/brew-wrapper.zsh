# Source from each human user's ~/.zshrc.
# Only these run directly as a non-owner; everything else needs the owner
# account (tested: info/search/config/outdated/deps/uses/leaves/desc write
# lock files into the prefix and fail for non-owners).
# The owner account cannot enter your home folder. The owner-run commands start in
# /var/empty, or brew stops with "The current working directory must exist to run brew".
# Do not use /tmp: any user can write there, and brew runs a Brewfile it finds in the
# current folder as the owner.
brew() {
  case "$1" in
    --prefix|--cellar|--repository|--version|list|ls|home)
      command brew "$@" ;;
    *)
      (cd /var/empty && command brew as-brew-user "$@") ;;
  esac
}
