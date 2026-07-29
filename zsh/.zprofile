# Login shells only, after /etc/zprofile.
#
# macOS /etc/zprofile runs path_helper, which discards the PATH ordering set in
# ~/.zshenv. Re-apply it so Homebrew keeps precedence over /usr/bin; the module
# is idempotent (see ~/.zsh/path-macos.zsh).
case "$OSTYPE" in
  darwin*)
    [[ -r ~/.zsh/path-macos.zsh ]] && source ~/.zsh/path-macos.zsh
    ;;
esac
