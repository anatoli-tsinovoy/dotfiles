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
  # Check Termux BEFORE Linux (Termux also returns "Linux" from uname)
  if [[ -n "${TERMUX_VERSION:-}" ]] || [[ "${PREFIX:-}" == *"com.termux"* ]]; then
    echo "termux"
    return
  fi
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
  elif [[ "$os" == "termux" ]]; then
    pkg install -y stow
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

install_termux_prerequisites() {
  if ! command -v curl &>/dev/null || ! command -v git &>/dev/null || ! command -v unzip &>/dev/null; then
    log_info "Installing prerequisites (curl, git, unzip)..."
    pkg update -y
    pkg install -y curl git unzip
  fi
}

install_termux_font() {
  local font_file="$HOME/.termux/font.ttf"
  local hack_version="v3.003"
  local hack_url="https://github.com/source-foundry/Hack/releases/download/${hack_version}/Hack-${hack_version}-ttf.zip"
  local tmp_dir

  if [[ -f "$font_file" ]]; then
    log_ok "Termux font already installed"
    return 0
  fi

  log_info "Installing Hack font for Termux..."
  mkdir -p "$HOME/.termux"

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  curl -fsSL "$hack_url" -o "$tmp_dir/hack.zip"
  unzip -q "$tmp_dir/hack.zip" -d "$tmp_dir"

  # Use Regular weight as the terminal font
  cp "$tmp_dir/ttf/Hack-Regular.ttf" "$font_file"

  # Reload settings if available
  if command -v termux-reload-settings &>/dev/null; then
    termux-reload-settings
  fi

  log_ok "Hack font installed"
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
  elif [[ "$os" == "termux" ]]; then
    install_termux_prerequisites
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

  elif [[ "$os" == "termux" ]]; then
    # === Termux Setup ===
    log_info "Installing Termux packages..."
    bash "$SCRIPT_DIR/scripts/termux/install-packages.sh"

    log_info "Installing Termux font..."
    install_termux_font
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
  rm -f ~/.zshrc ~/.zshrc.macos ~/.zshrc.linux ~/.zshrc.termux ~/.p10k.zsh
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

  elif [[ "$os" == "termux" ]]; then
    # Termux-specific setup
    log_info "Applying Termux-specific settings..."

    # Create empty gitconfig.local (no OS-specific overrides needed)
    touch "$HOME/.gitconfig.local"

    # Stow Termux config (theme files, theme toggle script)
    # Only remove regular files (not symlinks) - stow doesn't conflict with its own symlinks
    # Preserve user files: colors.properties, font.ttf, .current-theme
    log_info "Stowing Termux configuration..."
    mkdir -p ~/.termux ~/.local/bin
    [[ -f ~/.termux/colors.properties.light && ! -L ~/.termux/colors.properties.light ]] && rm -f ~/.termux/colors.properties.light
    [[ -f ~/.termux/colors.properties.dark && ! -L ~/.termux/colors.properties.dark ]] && rm -f ~/.termux/colors.properties.dark
    [[ -f ~/.local/bin/termux-theme-toggle && ! -L ~/.local/bin/termux-theme-toggle ]] && rm -f ~/.local/bin/termux-theme-toggle
    run_stow -t ~ termux

    # Initialize colors.properties with dark theme (uses copy, not symlink)
    if [[ ! -f "$HOME/.termux/colors.properties" ]]; then
      cp "$SCRIPT_DIR/termux/.termux/colors.properties.dark" "$HOME/.termux/colors.properties"
      echo "dark" > "$HOME/.termux/.current-theme"
      log_ok "Initialized Termux theme to dark"
    fi

    # Set zsh as default shell
    if [[ "$(basename "$SHELL")" != "zsh" ]]; then
      log_info "Setting zsh as default shell..."
      chsh -s zsh
      log_ok "Default shell set to zsh (restart Termux to apply)"
    fi
  fi

  # Tailscale + ET setup (skip on Termux - requires systemd)
  if [[ "$os" != "termux" ]]; then
    log_info "Optional: Tailscale + Eternal Terminal setup (requires confirmation)..."
    bash "$SCRIPT_DIR/scripts/tailscale-et.sh" || true
  fi

  log_ok "Bootstrap complete! Open a new shell to apply changes."
}

main "$@"
