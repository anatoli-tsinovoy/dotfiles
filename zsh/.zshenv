# OS-specific environment setup (runs before .zshrc)
case "$(uname -s)" in
  Darwin)
    [[ -f ~/.zshenv.macos ]] && source ~/.zshenv.macos
    ;;
  Linux)
    [[ -f ~/.zshenv.linux ]] && source ~/.zshenv.linux
    ;;
esac
