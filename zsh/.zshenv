# OS-specific environment setup (runs before .zshrc)
# Ubuntu's global zshrc runs compinit unless the user owns completion setup.
skip_global_compinit=1
case "$OSTYPE" in
  darwin*)
    [[ -f ~/.zshenv.macos ]] && source ~/.zshenv.macos
    ;;
  linux*)
    [[ -f ~/.zshenv.linux ]] && source ~/.zshenv.linux
    ;;
esac
. "$HOME/.cargo/env"
