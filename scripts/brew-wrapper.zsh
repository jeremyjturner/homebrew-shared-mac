# Source from each human user's ~/.zshrc.
# Only these run directly as a non-owner; everything else needs the owner
# account (tested: info/search/config/outdated/deps/uses/leaves/desc write
# lock files into the prefix and fail for non-owners).
brew() {
  case "$1" in
    --prefix|--cellar|--repository|--version|list|ls|home)
      command brew "$@" ;;
    *)
      command brew as-brew-user "$@" ;;
  esac
}
