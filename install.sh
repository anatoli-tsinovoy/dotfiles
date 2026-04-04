#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

log_info() { echo "ℹ️  $*"; }
log_ok() { echo "✅ $*"; }
log_skip() { echo "⏭️  $*"; }
log_warn() { echo "⚠️  $*"; }

STOW_FORCE=0
STOW_ADOPT=0

usage() {
  cat <<'EOF'
Usage: ./install.sh [--force] [--adopt]

Options:
  --force   Remove conflicting targets before stow
  --adopt   Adopt existing files into stow packages
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
    --force)
      STOW_FORCE=1
      shift
      ;;
    --adopt)
      STOW_ADOPT=1
      shift
      ;;
    -h | --help)
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
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

detect_os() {
  # Check Termux BEFORE Linux (Termux also returns "Linux" from uname)
  if [ -n "${TERMUX_VERSION:-}" ]; then
    echo "termux"
    return
  fi
  case "${PREFIX:-}" in
  *com.termux*)
    echo "termux"
    return
    ;;
  esac
  case "$(uname -s)" in
  Darwin) echo "mac" ;;
  Linux) echo "linux" ;;
  *) echo "other" ;;
  esac
}

detect_linux_distro() {
  if [ ! -f /etc/os-release ]; then
    echo "unknown"
    return
  fi

  os_id=$(sed -n 's/^ID=//p' /etc/os-release | head -n 1)
  os_id=${os_id#\"}
  os_id=${os_id%\"}

  if [ -n "$os_id" ]; then
    echo "$os_id"
  else
    echo "unknown"
  fi
}

detect_linux_version() {
  if [ ! -f /etc/os-release ]; then
    echo "unknown"
    return
  fi

  os_version=$(sed -n 's/^VERSION_ID=//p' /etc/os-release | head -n 1)
  os_version=${os_version#\"}
  os_version=${os_version%\"}

  if [ -n "$os_version" ]; then
    echo "$os_version"
  else
    echo "unknown"
  fi
}

detect_linux_arch() {
  linux_distro="${1:-unknown}"

  if [ "$linux_distro" = "alpine" ] && command -v apk >/dev/null 2>&1; then
    apk_arch=$(apk --print-arch 2>/dev/null || true)
    case "$apk_arch" in
    x86)
      echo "x86"
      return
      ;;
    x86_64)
      echo "x86_64"
      return
      ;;
    aarch64)
      echo "aarch64"
      return
      ;;
    esac
  fi

  case "$(uname -m)" in
  x86_64)
    echo "x86_64"
    ;;
  aarch64 | arm64)
    echo "aarch64"
    ;;
  i386 | i486 | i586 | i686 | x86)
    echo "x86"
    ;;
  *)
    uname -m
    ;;
  esac
}

is_ish_environment() {
  if uname -r 2>/dev/null | grep -qi 'ish'; then
    return 0
  fi

  if [ -f /proc/version ] && grep -qi 'ish' /proc/version 2>/dev/null; then
    return 0
  fi

  return 1
}

detect_deployment_target() {
  os="$1"
  linux_distro="${2:-unknown}"
  linux_arch="${3:-unknown}"

  if [ "$os" = "linux" ] && [ "$linux_distro" = "alpine" ] && [ "$linux_arch" = "x86" ] && is_ish_environment; then
    echo "ish"
    return
  fi

  echo "$os"
}

print_alpine_upgrade_guide() {
  deployment_target="${1:-linux}"

  echo ""
  echo "╔══════════════════════════════════════════════════════════════════╗"
  echo "║                     Alpine upgrade required                    ║"
  echo "╠══════════════════════════════════════════════════════════════════╣"
  echo "║ Bun needs a newer Alpine release than 3.14.                    ║"
  echo "║ Upgrade this machine to Alpine 3.20+ and rerun ./install.sh.   ║"
  echo "╚══════════════════════════════════════════════════════════════════╝"
  echo ""
  log_warn "Recommended upgrade flow:"
  if [ "$deployment_target" = "ish" ]; then
    echo "  1. Update the iSH app before changing Alpine repositories."
    echo "     Older iSH builds can hit 'Bad system call' on newer Alpine packages."
    echo "  2. Back up /etc/apk/repositories and any important data."
    echo "  3. Update every v3.14 entry in /etc/apk/repositories to v3.20."
    echo "  4. Run: apk update"
    echo "  5. Run: apk upgrade --available"
    echo "  6. Restart iSH if apk or login tools behave strangely."
    echo "  7. Re-run: sh ./install.sh"
  else
    echo "  1. Back up important data and confirm you can restore access."
    echo "  2. Update every v3.14 entry in /etc/apk/repositories to v3.20."
    echo "  3. Run: apk update"
    echo "  4. Run: apk upgrade --available"
    echo "  5. Reboot the machine."
    echo "  6. Re-run: sh ./install.sh"
  fi
  echo ""
  if [ "$deployment_target" = "ish" ]; then
    log_warn "Continuing install in iSH compatibility mode; unsupported x86 tools will be skipped."
  else
    log_warn "Continuing install, but Bun and Bun-based tools will be skipped on Alpine 3.14.x."
  fi
}

require_supported_alpine() {
  linux_distro="$1"
  linux_version="$2"
  deployment_target="${3:-linux}"

  if [ "$linux_distro" = "alpine" ]; then
    case "$linux_version" in
    3.14*)
      print_alpine_upgrade_guide "$deployment_target"
      ;;
    esac
  fi
}

install_alpine_packages() {
  log_info "Installing Alpine packages..."
  run_privileged apk add --no-cache \
    bash \
    build-base \
    ca-certificates \
    cmake \
    coreutils \
    curl \
    findutils \
    git \
    grep \
    gzip \
    libc6-compat \
    linux-headers \
    make \
    sed \
    stow \
    sudo \
    tar \
    unzip \
    xz \
    zsh
}

install_alpine_prerequisites() {
  log_info "Installing Alpine prerequisites (curl, git)..."
  run_privileged apk add --no-cache ca-certificates curl git
}

install_stow() {
  os="$1"
  linux_distro="${2:-unknown}"
  if command -v stow >/dev/null 2>&1; then
    log_ok "stow already installed"
    return 0
  fi

  log_info "Installing stow..."
  if [ "$os" = "mac" ]; then
    brew install stow
  elif [ "$os" = "termux" ]; then
    pkg install -y stow
  elif [ "$os" = "linux" ]; then
    if [ "$linux_distro" = "alpine" ]; then
      run_privileged apk add --no-cache stow
    else
      run_privileged apt-get update && run_privileged apt-get install -y stow
    fi
  fi
}

install_aptfile() {
  if command -v aptfile >/dev/null 2>&1; then
    log_ok "aptfile already installed"
    return 0
  fi

  log_info "Installing aptfile (Brewfile equivalent for apt)..."
  run_privileged curl -o /usr/local/bin/aptfile https://raw.githubusercontent.com/seatgeek/bash-aptfile/master/bin/aptfile
  run_privileged chmod +x /usr/local/bin/aptfile
  log_ok "aptfile installed"
}

setup_ohmyzsh() {
  OMZ="$HOME/.oh-my-zsh"
  OMZ_CUSTOM="${OMZ}/custom"

  if [ ! -d "$OMZ" ]; then
    log_info "Installing oh-my-zsh (unattended)…"
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    mkdir -p "$OMZ_CUSTOM"
  else
    log_ok "oh-my-zsh already present"
  fi
}

setup_p10k() {
  OMZ_CUSTOM="$HOME/.oh-my-zsh/custom"
  P10K_DIR="$OMZ_CUSTOM/themes/powerlevel10k"

  if [ ! -d "$P10K_DIR" ]; then
    log_info "Installing powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
  else
    log_ok "powerlevel10k already present"
  fi
}

setup_zsh_plugins() {
  OMZ_CUSTOM="$HOME/.oh-my-zsh/custom"

  plugin_dir="$OMZ_CUSTOM/plugins/zsh-syntax-highlighting"
  if [ -d "$plugin_dir/.git" ]; then
    log_ok "zsh-syntax-highlighting already installed"
  else
    rm -rf "$plugin_dir"
    log_info "Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugin_dir"
  fi

  plugin_dir="$OMZ_CUSTOM/plugins/zsh-autosuggestions"
  if [ -d "$plugin_dir/.git" ]; then
    log_ok "zsh-autosuggestions already installed"
  else
    rm -rf "$plugin_dir"
    log_info "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$plugin_dir"
  fi
}

install_linux_prerequisites() {
  linux_distro="$1"
  if ! command -v curl >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1; then
    if [ "$linux_distro" = "alpine" ]; then
      install_alpine_prerequisites
    else
      log_info "Installing prerequisites (curl, git)..."
      run_privileged apt-get update
      run_privileged apt-get install -y curl git ca-certificates
    fi
  fi
}

install_termux_prerequisites() {
  if ! command -v curl >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
    log_info "Installing prerequisites (curl, git, unzip)..."
    pkg update -y
    pkg install -y curl git unzip
  fi
}

install_termux_font() {
  font_file="$HOME/.termux/font.ttf"
  hack_version="v3.003"
  hack_url="https://github.com/source-foundry/Hack/releases/download/${hack_version}/Hack-${hack_version}-ttf.zip"

  if [ -f "$font_file" ]; then
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
  if command -v termux-reload-settings >/dev/null 2>&1; then
    termux-reload-settings
  fi

  log_ok "Hack font installed"
}

stow_force_cleanup() {
  target="$HOME"
  expect_target=0

  for arg in "$@"; do
    if [ "$expect_target" -eq 1 ]; then
      target="$arg"
      expect_target=0
      continue
    fi

    case "$arg" in
    -t | --target)
      expect_target=1
      ;;
    esac
  done

  output=$(stow -n "$@" 2>&1 || true)
  printf '%s\n' "$output" | while IFS= read -r line; do
    case "$line" in
    *"existing target is not owned by stow: "*)
      conflict=${line##*existing target is not owned by stow: }
      path="$conflict"
      case "$conflict" in
      /*) ;;
      *) path="$target/$conflict" ;;
      esac
      log_warn "Force: removing conflicting target $path"
      rm -rf "$path"
      ;;
    esac
  done
}

run_stow() {
  if [ "$STOW_FORCE" -eq 1 ]; then
    stow_force_cleanup "$@"
  fi
  if [ "$STOW_ADOPT" -eq 1 ]; then
    stow --adopt "$@"
  else
    stow "$@"
  fi
}

main() {
  parse_args "$@"
  os="$(detect_os)"
  linux_distro="unknown"
  linux_version="unknown"
  linux_arch="unknown"
  deployment_target="$os"
  if [ "$os" = "linux" ]; then
    linux_distro="$(detect_linux_distro)"
    linux_version="$(detect_linux_version)"
    linux_arch="$(detect_linux_arch "$linux_distro")"
    deployment_target="$(detect_deployment_target "$os" "$linux_distro" "$linux_arch")"
  fi
  log_info "Detected OS: $os"
  if [ "$os" = "linux" ]; then
    log_info "Detected Linux distro: $linux_distro"
    log_info "Detected Linux version: $linux_version"
    log_info "Detected Linux architecture: $linux_arch"
  fi
  log_info "Detected deployment target: $deployment_target"

  require_supported_alpine "$linux_distro" "$linux_version" "$deployment_target"

  export DOTFILES_LINUX_DISTRO="$linux_distro"
  export DOTFILES_LINUX_VERSION="$linux_version"
  export DOTFILES_LINUX_ARCH="$linux_arch"
  export DOTFILES_DEPLOYMENT_TARGET="$deployment_target"

  if [ "$os" = "linux" ]; then
    install_linux_prerequisites "$linux_distro"
  elif [ "$os" = "termux" ]; then
    install_termux_prerequisites
  fi

  if [ "$os" = "mac" ]; then
    # === macOS Setup ===

    # Ensure Homebrew
    if ! command -v brew >/dev/null 2>&1; then
      if ! xcode-select -p >/dev/null 2>&1; then
        log_warn "Xcode Command Line Tools not found. Installing..."
        xcode-select --install || true
      fi
      /usr/bin/env bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      eval "$(/opt/homebrew/bin/brew shellenv)"
      eval "$(/opt/homebrew/bin/brew shellenv zsh)"
    fi

    log_info "Installing Homebrew packages..."
    brew bundle --file="$SCRIPT_DIR/Brewfile" --verbose || true

    log_info "Installing opencode via bun..."
    bun install -g opencode-ai@dev

    log_info "Applying macOS defaults..."
    "$SCRIPT_DIR/scripts/macos/macos-defaults.sh"

  elif [ "$os" = "linux" ]; then
    # === Linux Setup ===

    if [ "$linux_distro" = "alpine" ]; then
      install_alpine_packages
    else
      # Install aptfile tool
      install_aptfile

      log_info "Installing apt packages via Aptfile..."
      run_privileged aptfile "$SCRIPT_DIR/Aptfile"
    fi

    # Initialize git-lfs
    if command -v git-lfs >/dev/null 2>&1; then
      git lfs install
    fi

    log_info "Installing binary tools..."
    "$SCRIPT_DIR/scripts/linux/install-binaries.sh"

  elif [ "$os" = "termux" ]; then
    # === Termux Setup ===
    log_info "Installing Termux packages..."
    "$SCRIPT_DIR/scripts/termux/install-packages.sh"

    log_info "Installing Termux font..."
    install_termux_font
  fi

  # === Common Setup (both OS) ===

  install_stow "$os" "$linux_distro"

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
  run_stow -t ~ nvim git opencode glow tmux

  # Stow unified zsh package (contains .zshrc, .zshrc.macos, .zshrc.linux, .p10k.zsh)
  log_info "Stowing zsh configuration..."
  run_stow -t ~ zsh

  if [ "$os" = "mac" ]; then
    # Remove macOS-specific conflicts
    rm -rf ~/.config/aerospace ~/.config/iterm2
    rm -rf ~/Library/Application\ Support/Cursor/User

    # macOS-specific stow packages
    log_info "Stowing macOS-specific dotfiles..."
    run_stow -t ~ aerospace iterm2 cursor-macos private-macos

    # Create macOS-specific gitconfig.local
    cp "$SCRIPT_DIR/git/.gitconfig.macos" "$HOME/.gitconfig.local"

    # Compile Swift helpers
    if command -v swiftc >/dev/null 2>&1; then
      swiftc "$SCRIPT_DIR/aerospace/.config/aerospace/winbounds.swift" \
        -o "$SCRIPT_DIR/aerospace/.config/aerospace/winbounds"
    fi

    # Stow macOS shims (podman -> docker)
    log_info "Stowing macOS shims..."
    run_stow -t ~ -d shims macos

  elif [ "$os" = "linux" ]; then
    # Linux-specific setup
    log_info "Applying Linux-specific settings..."

    # Create empty gitconfig.local (no OS-specific overrides needed)
    touch "$HOME/.gitconfig.local"

    # Stow Linux shims (bun -> node)
    log_info "Stowing Linux shims..."
    run_stow -t ~ -d shims linux

  elif [ "$os" = "termux" ]; then
    # Termux-specific setup
    log_info "Applying Termux-specific settings..."

    # Create empty gitconfig.local (no OS-specific overrides needed)
    touch "$HOME/.gitconfig.local"

    # Stow Termux config with --no-folding to create file symlinks (not directory symlink)
    # This allows user files (font.ttf, colors.properties, etc.) to coexist with stowed themes
    log_info "Stowing Termux configuration..."
    mkdir -p ~/.termux ~/.local/bin
    run_stow --no-folding -t ~ termux

    # Initialize colors.properties with dark theme (uses copy, not symlink)
    if [ ! -f "$HOME/.termux/colors.properties" ]; then
      cp "$HOME/.termux/colors.properties.dark" "$HOME/.termux/colors.properties"
      echo "dark" >"$HOME/.termux/.current-theme"
      log_ok "Initialized Termux theme to dark"
    fi

    # Set zsh as default shell
    if [ "$(basename "$SHELL")" != "zsh" ]; then
      log_info "Setting zsh as default shell..."
      chsh -s zsh
      log_ok "Default shell set to zsh (restart Termux to apply)"
    fi
  fi

  # Tailscale + ET setup (skip on Termux - requires systemd)
  if [ "$os" != "termux" ] && [ "$deployment_target" != "ish" ]; then
    log_info "Optional: Tailscale + Eternal Terminal setup (requires confirmation)..."
    "$SCRIPT_DIR/scripts/tailscale-et.sh" || true
  elif [ "$deployment_target" = "ish" ]; then
    log_skip "Skipping Tailscale + ET on iSH (requires systemd, TUN/TAP, and Linux service management)"
  fi

  log_ok "Bootstrap complete! Open a new shell to apply changes."
}

main "$@"
