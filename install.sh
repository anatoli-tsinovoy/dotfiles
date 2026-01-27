#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd)"

log_info() { echo "ℹ️  $*"; }
log_ok() { echo "✅ $*"; }
log_warn() { echo "⚠️  $*"; }

STOW_FORCE=0

usage() {
  cat <<'EOF'
Usage: ./install.sh [--force]

Options:
  --force   Remove conflicting targets before stow
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force)
        STOW_FORCE=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        log_warn "Unknown argument: $1"
        shift
        ;;
    esac
  done
}

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

  local plugin_dir="$OMZ_CUSTOM/plugins/zsh-syntax-highlighting"
  if [[ -d "$plugin_dir/.git" ]]; then
    log_ok "zsh-syntax-highlighting already installed"
  else
    rm -rf "$plugin_dir"
    log_info "Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugin_dir"
  fi

  plugin_dir="$OMZ_CUSTOM/plugins/zsh-autosuggestions"
  if [[ -d "$plugin_dir/.git" ]]; then
    log_ok "zsh-autosuggestions already installed"
  else
    rm -rf "$plugin_dir"
    log_info "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$plugin_dir"
  fi
}

install_linux_prerequisites() {
  if ! command -v curl &>/dev/null || ! command -v git &>/dev/null; then
    log_info "Installing prerequisites (curl, git)..."
    run_privileged apt-get update
    run_privileged apt-get install -y curl git ca-certificates
  fi
}

stow_force_cleanup() {
  local args=("$@")
  local target="$HOME"
  local output

  for ((i=0; i<${#args[@]}; i++)); do
    if [[ "${args[$i]}" == "-t" || "${args[$i]}" == "--target" ]]; then
      target="${args[$((i + 1))]}"
    fi
  done

  output="$(stow -n "${args[@]}" 2>&1 || true)"
  while IFS= read -r line; do
    if [[ "$line" =~ existing\ target\ is\ not\ owned\ by\ stow:\ (.+)$ ]]; then
      local conflict="${BASH_REMATCH[1]}"
      local path="$conflict"
      if [[ "$conflict" != /* ]]; then
        path="$target/$conflict"
      fi
      log_warn "Force: removing conflicting target $path"
      rm -rf "$path"
    fi
  done <<< "$output"
}

run_stow() {
  if [[ $STOW_FORCE -eq 1 ]]; then
    stow_force_cleanup "$@"
  fi
  stow "$@"
}

main() {
  parse_args "$@"
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
    bash "$SCRIPT_DIR/scripts/macos/macos-defaults.sh"

    log_info "Optional: Tailscale SSH setup (requires confirmation)..."
    bash "$SCRIPT_DIR/scripts/macos/tailscale-ssh.sh" || true

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
    bash "$SCRIPT_DIR/scripts/linux/install-binaries.sh"
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
  rm -f ~/.zshenv ~/.zshenv.macos ~/.zshenv.linux
  rm -f ~/.zshrc ~/.zshrc.macos ~/.zshrc.linux ~/.p10k.zsh
  rm -f ~/.gitconfig ~/.vimrc
  rm -rf ~/.config/nvim ~/.config/opencode

  # Stow common packages (no --adopt: we want OUR files, not whatever exists)
  log_info "Stowing common dotfiles..."
  run_stow -t ~ nvim git opencode

  # Stow unified zsh package (contains .zshrc, .zshrc.macos, .zshrc.linux, .p10k.zsh)
  log_info "Stowing zsh configuration..."
  run_stow -t ~ zsh

  if [[ "$os" == "mac" ]]; then
    # Remove macOS-specific conflicts
    rm -rf ~/.config/aerospace ~/.config/iterm2
    rm -rf ~/Library/Application\ Support/Cursor/User

    # macOS-specific stow packages
    log_info "Stowing macOS-specific dotfiles..."
    run_stow -t ~ aerospace iterm2 cursor-macos

    # Create macOS-specific gitconfig.local
    cp "$SCRIPT_DIR/git/.gitconfig.macos" "$HOME/.gitconfig.local"

    # Compile Swift helpers
    if command -v swiftc &>/dev/null; then
      swiftc "$SCRIPT_DIR/aerospace/.config/aerospace/winbounds.swift" \
        -o "$SCRIPT_DIR/aerospace/.config/aerospace/winbounds"
    fi

    # Stow macOS shims (podman -> docker)
    log_info "Stowing macOS shims..."
    run_stow -t ~ -d shims macos

  elif [[ "$os" == "linux" ]]; then
    # Linux-specific setup
    log_info "Applying Linux-specific settings..."

    # Create empty gitconfig.local (no OS-specific overrides needed)
    touch "$HOME/.gitconfig.local"

    # Stow Linux shims (bun -> node)
    log_info "Stowing Linux shims..."
    run_stow -t ~ -d shims linux
  fi

  log_ok "Bootstrap complete! Open a new shell to apply changes."
}

main "$@"
