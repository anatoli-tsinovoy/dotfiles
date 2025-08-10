#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd)"
detect_os() {
  case "$(uname -s)" in
  Darwin) echo "mac" ;;
  Linux) echo "linux" ;;
  *) echo "other" ;;
  esac
}

main() {
  local os
  os="$(detect_os)"

  # Ensure Homebrew on mac (optional)
  if [[ "$os" == "mac" ]]; then
    if ! command -v brew >/dev/null 2>&1; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      eval "$(/opt/homebrew/bin/brew shellenv)" # Apple Silicon default
    fi
    brew bundle --file="$SCRIPT_DIR/Brewfile" || true
  fi

  # Install GNU Stow
  if ! command -v stow >/dev/null 2>&1; then
    if [[ "$os" == "mac" ]]; then
      brew install stow
    elif [[ 1 == 0 ]]; then
      echo "Placeholder for linux distros"
      sudo apt-get update && sudo apt-get install -y stow
    fi
  fi

  cd "$SCRIPT_DIR"

  # Adopt existing files (moves them into the package and replaces with symlink).
  # Run once carefully; remove --adopt afterwards.
  # stow --adopt -t ~ nvim
  stow --adopt -t ~ nvim
  if [[ "$os" == "mac" ]]; then
    # stow --adopt aerospace iterm2 cursor-macos zsh-macos
    stow --adopt -t ~ aerospace iterm2 cursor-macos zsh-macos
    # Apply macOS defaults if you have them:
    [[ -x mac/.macos ]] && bash mac/.macos || true
  elif [[ 1 == 0 ]]; then
    echo "Placeholder for linux distros"
  fi

  echo "Done. Open a new shell."
}

main "$@"
