#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd)"

log_info() { echo "ℹ️  $*"; }
log_ok() { echo "✅ $*"; }
log_warn() { echo "⚠️  $*"; }

run_privileged() {
  if [[ $EUID -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

detect_os() {
  case "$(uname -s)" in
    Darwin) echo "mac" ;;
    Linux) echo "linux" ;;
    *) echo "other" ;;
  esac
}

install_stow() {
  local os="$1"
  if command -v stow &>/dev/null; then
    log_ok "stow already installed"
    return 0
  fi
  
  log_info "Installing stow..."
  if [[ "$os" == "mac" ]]; then
    brew install stow
  elif [[ "$os" == "linux" ]]; then
    run_privileged apt-get update && run_privileged apt-get install -y stow
  fi
}

install_aptfile() {
  if command -v aptfile &>/dev/null; then
    log_ok "aptfile already installed"
    return 0
  fi
  
  log_info "Installing aptfile (Brewfile equivalent for apt)..."
  run_privileged curl -o /usr/local/bin/aptfile https://raw.githubusercontent.com/seatgeek/bash-aptfile/master/bin/aptfile
  run_privileged chmod +x /usr/local/bin/aptfile
  log_ok "aptfile installed"
}

setup_ohmyzsh() {
  local OMZ="$HOME/.oh-my-zsh"
  local OMZ_CUSTOM="${OMZ}/custom"
  
  if [[ ! -d $OMZ ]]; then
    log_info "Installing oh-my-zsh (unattended)…"
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    mkdir -p "$OMZ_CUSTOM"
  else
    log_ok "oh-my-zsh already present"
  fi
}

setup_p10k() {
  local OMZ_CUSTOM="$HOME/.oh-my-zsh/custom"
  local P10K_DIR="$OMZ_CUSTOM/themes/powerlevel10k"
  
  if [[ ! -d "$P10K_DIR" ]]; then
    log_info "Installing powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
  else
    log_ok "powerlevel10k already present"
  fi
}

setup_zsh_plugins() {
  local OMZ_CUSTOM="$HOME/.oh-my-zsh/custom"
  
  if [[ ! -d "$OMZ_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    log_info "Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$OMZ_CUSTOM/plugins/zsh-syntax-highlighting"
  fi
  
  if [[ ! -d "$OMZ_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    log_info "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$OMZ_CUSTOM/plugins/zsh-autosuggestions"
  fi
}

install_linux_prerequisites() {
  if ! command -v curl &>/dev/null || ! command -v git &>/dev/null; then
    log_info "Installing prerequisites (curl, git)..."
    run_privileged apt-get update
    run_privileged apt-get install -y curl git ca-certificates
  fi
}

main() {
  local os
  os="$(detect_os)"
  log_info "Detected OS: $os"

  if [[ "$os" == "linux" ]]; then
    install_linux_prerequisites
  fi

  if [[ "$os" == "mac" ]]; then
    # === macOS Setup ===
    
    # Ensure Homebrew
    if ! command -v brew &>/dev/null; then
      if ! xcode-select -p &>/dev/null; then
        log_warn "Xcode Command Line Tools not found. Installing..."
        xcode-select --install || true
      fi
      /usr/bin/env bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      eval "$(/opt/homebrew/bin/brew shellenv)"
      eval "$(/opt/homebrew/bin/brew shellenv zsh)"
    fi
    
    log_info "Installing Homebrew packages..."
    brew bundle --file="$SCRIPT_DIR/Brewfile" --verbose || true
    
    log_info "Applying macOS defaults..."
    bash "$SCRIPT_DIR/macos-defaults.sh"
    
  elif [[ "$os" == "linux" ]]; then
    # === Linux Setup ===
    
    # Install aptfile tool
    install_aptfile
    
    log_info "Installing apt packages via Aptfile..."
    run_privileged aptfile "$SCRIPT_DIR/Aptfile"
    
    # Initialize git-lfs
    if command -v git-lfs &>/dev/null; then
      git lfs install
    fi
    
    log_info "Installing binary tools..."
    bash "$SCRIPT_DIR/install-binaries.sh"
  fi

  # === Common Setup (both OS) ===
  
  install_stow "$os"
  
  cd "$SCRIPT_DIR"
  
  # Setup oh-my-zsh, powerlevel10k, and plugins
  setup_ohmyzsh
  setup_p10k
  setup_zsh_plugins
  
  # Remove files that would conflict with stow
  # (oh-my-zsh creates a default .zshrc that we don't want)
  log_info "Removing conflicting files before stow..."
  rm -f ~/.zshrc ~/.zshrc.macos ~/.zshrc.linux ~/.p10k.zsh
  rm -f ~/.gitconfig ~/.vimrc
  rm -rf ~/.config/nvim ~/.config/opencode
  
  # Stow common packages (no --adopt: we want OUR files, not whatever exists)
  log_info "Stowing common dotfiles..."
  stow -t ~ nvim git opencode
  
  # Stow unified zsh package (contains .zshrc, .zshrc.macos, .zshrc.linux, .p10k.zsh)
  log_info "Stowing zsh configuration..."
  stow -t ~ zsh
  
  if [[ "$os" == "mac" ]]; then
    # Remove macOS-specific conflicts
    rm -rf ~/.config/aerospace ~/.config/iterm2
    rm -rf ~/Library/Application\ Support/Cursor/User
    rm -rf ~/.warp
    
    # macOS-specific stow packages
    log_info "Stowing macOS-specific dotfiles..."
    stow -t ~ aerospace iterm2 cursor-macos warp-macos
    
    # Create macOS-specific gitconfig.local
    cp "$SCRIPT_DIR/git/.gitconfig.macos" "$HOME/.gitconfig.local"
    
    # Compile Swift helpers
    if command -v swiftc &>/dev/null; then
      swiftc "$SCRIPT_DIR/aerospace/.config/aerospace/winbounds.swift" \
        -o "$SCRIPT_DIR/aerospace/.config/aerospace/winbounds"
    fi
    
    # Apply podman shim (macOS uses podman, shim provides 'docker' command)
    cp "$SCRIPT_DIR/docker-shim.sh" /opt/homebrew/bin/docker
    
  elif [[ "$os" == "linux" ]]; then
    # Linux-specific setup
    log_info "Applying Linux-specific settings..."
    
    # Create empty gitconfig.local (no OS-specific overrides needed)
    touch "$HOME/.gitconfig.local"
    
    # No docker shim needed on Linux (native Docker)
  fi

  log_ok "Bootstrap complete! Open a new shell to apply changes."
}

main "$@"
