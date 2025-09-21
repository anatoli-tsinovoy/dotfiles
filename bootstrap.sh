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
      # Xcode CLT (needed for brew on clean macs)
      if ! xcode-select -p >/dev/null 2>&1; then
        warn "Xcode Command Line Tools not found. Installing (you may see a popup)…"
        xcode-select --install || true
      fi
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      eval "$(/opt/homebrew/bin/brew shellenv)" # Apple Silicon default
    fi
    brew bundle --file="$SCRIPT_DIR/Brewfile" || true
  fi

  # mac System settings
  if [[ "$os" == "mac" ]]; then
    defaults write -g NSAutomaticWindowAnimationsEnabled -bool false
    defaults write -g AppleMenuBarVisibleInFullscreen -bool false
    defaults write NSGlobalDomain _HIHideMenuBar -bool true
    defaults write -g ApplePressAndHoldEnabled -bool false
    defaults write -g NSWindowShouldDragOnGesture -bool true
    killall SystemUIServer
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
  # stow -t ~ nvim
  stow --adopt -t ~ nvim git
  if [[ "$os" == "mac" ]]; then
    # stow -t ~ aerospace iterm2 cursor-macos warp-macos
    stow --adopt -t ~ aerospace iterm2 cursor-macos warp-macos
    # Apply macOS defaults if you have them:
    [[ -x mac/.macos ]] && bash mac/.macos || true
  elif [[ 1 == 0 ]]; then
    echo "Placeholder for linux distros"
  fi

  OMZ="$HOME/.oh-my-zsh"
  OMZ_CUSTOM="${OMZ}/custom"
  # oh-my-zsh (unattended, don’t auto-run zsh, don’t chsh)
  if [[ ! -d $OMZ ]]; then
    echo "Installing oh-my-zsh (unattended)…"
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    mkdir -p "$OMZ_CUSTOM"
  else
    echo "oh-my-zsh already present. Skipping."
  fi

  # prepare custom dir

  # (optional) submodules for external plugins/themes
  git submodule update --init --recursive
  if [[ "$os" == "mac" ]]; then
    # stow -t ~ zsh-macos
    stow --adopt -t ~ zsh-macos
  elif [[ 1 == 0 ]]; then
    echo "Placeholder for linux distros"
  fi

  echo "Done. Open a new shell."
}

main "$@"
