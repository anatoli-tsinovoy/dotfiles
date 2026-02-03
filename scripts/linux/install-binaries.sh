#!/usr/bin/env bash
# install-binaries.sh - Install tools not available via apt
# These require manual binary downloads, install scripts, or post-apt tooling
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# === Helper functions ===
log_info() { echo "ℹ️  $*"; }
log_ok() { echo "✅ $*"; }
log_skip() { echo "⏭️  $*"; }
log_warn() { echo "⚠️  $*"; }

command_exists() { command -v "$1" &>/dev/null; }

run_privileged() {
  if [[ $EUID -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

get_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
  x86_64) echo "x86_64" ;;
  aarch64 | arm64) echo "aarch64" ;;
  *) echo "$arch" ;;
  esac
}

get_arch_deb() {
  local arch
  arch="$(dpkg --print-architecture 2>/dev/null || echo "amd64")"
  echo "$arch"
}

is_inside_container() {
  [[ -f /.dockerenv ]] || [[ -n "${container:-}" ]] || grep -q docker /proc/1/cgroup 2>/dev/null
}

# Fetch latest GitHub release version with rate limit detection
# Usage: get_github_release_version "owner/repo"
# Returns: version string (without 'v' prefix) or exits with error message
get_github_release_version() {
  local repo="$1"
  local response
  local version

  response=$(curl -sSf "https://api.github.com/repos/${repo}/releases/latest" 2>&1) || {
    if echo "$response" | grep -qi "rate limit\|API rate limit"; then
      log_warn "GitHub API rate limit exceeded!"
      log_warn "Wait a bit, then run: ./install.sh"
      log_warn "Or set GITHUB_TOKEN env var for higher limits"
      return 2
    fi
    log_warn "Failed to fetch release info for $repo: $response"
    return 1
  }

  version=$(echo "$response" | grep -Po '"tag_name": "v?\K[0-9.]+' | head -1)
  if [[ -z "$version" ]]; then
    log_warn "Could not parse version from GitHub response for $repo"
    return 1
  fi

  echo "$version"
}

# === Installation functions ===

install_neovim() {
  if command_exists nvim; then
    local current_version
    current_version=$(nvim --version | head -1 | grep -oP 'v\K[0-9.]+')
    log_skip "neovim already installed (v${current_version})"
    return 0
  fi

  log_info "Installing neovim from GitHub releases..."
  local arch
  arch=$(get_arch)

  local arch_name
  case "$arch" in
  x86_64) arch_name="x86_64" ;;
  aarch64) arch_name="arm64" ;;
  *)
    log_warn "Unsupported architecture for neovim: $arch"
    return 1
    ;;
  esac

  local url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${arch_name}.tar.gz"
  local install_dir="/opt/nvim"

  local tmpdir
  tmpdir=$(mktemp -d)
  curl -LSsf "$url" -o "$tmpdir/nvim.tar.gz"

  run_privileged rm -rf "$install_dir"
  run_privileged mkdir -p "$install_dir"
  run_privileged tar -xzf "$tmpdir/nvim.tar.gz" -C "$install_dir" --strip-components=1

  run_privileged ln -sf "$install_dir/bin/nvim" /usr/local/bin/nvim

  rm -rf "$tmpdir"
  log_ok "neovim installed to $install_dir"
}

install_uv() {
  if command_exists uv; then
    log_skip "uv already installed ($(uv --version))"
    return 0
  fi
  log_info "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  # Source the env for this session
  export PATH="$HOME/.local/bin:$PATH"
  log_ok "uv installed"
}

install_bun() {
  if command_exists bun; then
    log_skip "bun already installed ($(bun --version))"
    return 0
  fi
  log_info "Installing bun..."
  curl -fsSL https://bun.sh/install | bash
  # Source for this session
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
  log_ok "bun installed"
}

install_cargo() {
  if command_exists cargo; then
    log_skip "cargo already installed ($(cargo --version))"
    return 0
  fi
  log_info "Installing rustup/cargo..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
  export PATH="$HOME/.cargo/bin:$PATH"
  log_ok "cargo installed"
}

install_glow() {
  if command_exists glow; then
    log_skip "glow already installed ($(glow --version 2>&1 | head -1))"
    return 0
  fi

  log_info "Installing glow from GitHub releases..."
  local version arch arch_name
  version=$(get_github_release_version "charmbracelet/glow") || return 1
  arch=$(get_arch)

  case "$arch" in
  x86_64) arch_name="x86_64" ;;
  aarch64) arch_name="arm64" ;;
  *)
    log_warn "Unsupported architecture for glow: $arch"
    return 1
    ;;
  esac

  local tmpdir
  tmpdir=$(mktemp -d)
  curl -LSsf "https://github.com/charmbracelet/glow/releases/download/v${version}/glow_${version}_Linux_${arch_name}.tar.gz" -o "$tmpdir/glow.tar.gz"
  tar -xzf "$tmpdir/glow.tar.gz" -C "$tmpdir" --strip-components=1

  local bindir="$HOME/.local/bin"
  mkdir -p "$bindir"
  mv "$tmpdir/glow" "$bindir/"
  chmod +x "$bindir/glow"
  rm -rf "$tmpdir"
  log_ok "glow installed to $bindir/glow"
}

install_dua() {
  if command_exists dua; then
    log_skip "dua already installed ($(dua --version 2>&1 | head -1))"
    return 0
  fi
  log_info "Installing dua-cli..."
  local version arch
  version=$(get_github_release_version "Byron/dua-cli") || return 1
  arch=$(get_arch)

  curl -LSfs https://raw.githubusercontent.com/Byron/dua-cli/master/ci/install.sh |
    sh -s -- --git Byron/dua-cli --target "${arch}-unknown-linux-musl" --crate dua --tag "v${version}"
  log_ok "dua installed"
}

install_tlrc() {
  if command_exists tldr; then
    log_skip "tlrc already installed ($(tldr --version))"
    return 0
  fi

  local arch
  arch=$(get_arch)

  if [[ "$arch" == "x86_64" ]]; then
    log_info "Installing tlrc from prebuilt binary..."
    local version
    version=$(get_github_release_version "tldr-pages/tlrc") || return 1

    local target="x86_64-unknown-linux-musl"
    local tmpdir
    tmpdir=$(mktemp -d)
    curl -LSsf "https://github.com/tldr-pages/tlrc/releases/download/v${version}/tlrc-v${version}-${target}.tar.gz" -o "$tmpdir/tlrc.tar.gz"
    tar -xzf "$tmpdir/tlrc.tar.gz" -C "$tmpdir"

    local bindir="$HOME/.local/bin"
    mkdir -p "$bindir"
    mv "$tmpdir/tldr" "$bindir/"
    chmod +x "$bindir/tldr"
    rm -rf "$tmpdir"
    log_ok "tlrc installed to $bindir/tldr"
  else
    log_info "Installing tlrc via cargo (no ARM64 prebuilt available)..."
    install_cargo
    cargo install tlrc
    log_ok "tlrc installed via cargo"
  fi
}

install_thefuck() {
  if command_exists thefuck; then
    log_skip "thefuck already installed"
    return 0
  fi
  if ! command_exists uv; then
    log_warn "uv not found, skipping thefuck installation"
    return 1
  fi

  log_info "Installing thefuck via uv (with Python 3.11)..."
  uv tool install --python 3.11 thefuck
  log_ok "thefuck installed"
}

install_ruff() {
  if command_exists ruff; then
    log_skip "ruff already installed ($(ruff --version))"
    return 0
  fi
  if ! command_exists uv; then
    log_warn "uv not found, skipping ruff installation"
    return 1
  fi

  log_info "Installing ruff via uv..."
  uv tool install ruff
  log_ok "ruff installed"
}

install_ty() {
  if command_exists ty; then
    log_skip "ty already installed ($(ty --version))"
    return 0
  fi
  if ! command_exists uv; then
    log_warn "uv not found, skipping ty installation"
    return 1
  fi

  log_info "Installing ty via uv..."
  uv tool install ty
  log_ok "ty installed"
}

install_yt_dlp() {
  if command_exists yt-dlp; then
    log_skip "yt-dlp already installed ($(yt-dlp --version))"
    return 0
  fi
  if ! command_exists uv; then
    log_warn "uv not found, skipping yt-dlp installation"
    return 1
  fi

  log_info "Installing yt-dlp via uv..."
  uv tool install yt-dlp
  log_ok "yt-dlp installed"
}

install_emojify() {
  if command_exists emojify; then
    log_skip "emojify already installed"
    return 0
  fi
  log_info "Installing emojify (shell emoji converter)..."
  local install_dir="${HOME}/.local/bin"
  mkdir -p "$install_dir"
  curl -fsSL https://raw.githubusercontent.com/mrowa44/emojify/master/emojify -o "${install_dir}/emojify"
  chmod +x "${install_dir}/emojify"
  log_ok "emojify installed to ${install_dir}/emojify"
}

install_opencode() {
  if command_exists opencode; then
    log_skip "opencode already installed"
    return 0
  fi
  if ! command_exists bun; then
    log_warn "bun not found, skipping opencode installation"
    return 1
  fi

  log_info "Installing opencode via bun..."
  bun install -g opencode-ai@latest
  log_ok "opencode installed"
}

install_bash_language_server() {
  if command_exists bash-language-server; then
    log_skip "bash-language-server already installed"
    return 0
  fi
  if ! command_exists bun; then
    log_warn "bun not found, skipping bash-language-server installation"
    return 1
  fi

  log_info "Installing bash-language-server via bun..."
  bun install -g bash-language-server
  log_ok "bash-language-server installed"
}

install_yaml_language_server() {
  if command_exists yaml-language-server; then
    log_skip "yaml-language-server already installed"
    return 0
  fi
  if ! command_exists bun; then
    log_warn "bun not found, skipping yaml-language-server installation"
    return 1
  fi

  log_info "Installing yaml-language-server via bun..."
  bun install -g yaml-language-server
  log_ok "yaml-language-server installed"
}

install_viu() {
  if command_exists viu; then
    log_skip "viu already installed ($(viu --version 2>&1 | head -1))"
    return 0
  fi

  log_info "Installing viu from GitHub releases..."
  local version arch
  version=$(curl -s "https://api.github.com/repos/atanunq/viu/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+')
  arch=$(get_arch)

  local target
  case "$arch" in
  x86_64) target="x86_64-unknown-linux-musl" ;;
  aarch64) target="aarch64-unknown-linux-musl" ;;
  *)
    log_warn "Unsupported architecture for viu: $arch"
    return 1
    ;;
  esac

  local tmpdir
  tmpdir=$(mktemp -d)
  curl -LSsf "https://github.com/atanunq/viu/releases/download/v${version}/viu-${target}" -o "$tmpdir/viu"

  local bindir="$HOME/.local/bin"
  mkdir -p "$bindir"
  mv "$tmpdir/viu" "$bindir/"
  chmod +x "$bindir/viu"
  rm -rf "$tmpdir"
  log_ok "viu installed to $bindir/viu"
}

install_lazydocker() {
  # Only install if NOT inside a container
  if is_inside_container; then
    log_skip "Inside container, skipping lazydocker"
    return 0
  fi

  if command_exists lazydocker; then
    log_skip "lazydocker already installed ($(lazydocker --version 2>&1 | head -1))"
    return 0
  fi

  log_info "Installing lazydocker..."
  local version arch
  version=$(get_github_release_version "jesseduffield/lazydocker") || return 1
  arch=$(get_arch)

  local arch_name
  case "$arch" in
  x86_64) arch_name="x86_64" ;;
  aarch64) arch_name="arm64" ;;
  *)
    log_warn "Unsupported architecture for lazydocker: $arch"
    return 1
    ;;
  esac

  local tmpdir
  tmpdir=$(mktemp -d)
  curl -LSsf "https://github.com/jesseduffield/lazydocker/releases/latest/download/lazydocker_${version}_Linux_${arch_name}.tar.gz" -o "$tmpdir/lazydocker.tar.gz"
  tar -xzf "$tmpdir/lazydocker.tar.gz" -C "$tmpdir"

  local bindir="$HOME/.local/bin"
  mkdir -p "$bindir"
  mv "$tmpdir/lazydocker" "$bindir/"
  chmod +x "$bindir/lazydocker"
  rm -rf "$tmpdir"
  log_ok "lazydocker installed to $bindir/lazydocker"
}

install_lazyvim() {
  local nvim_config="$HOME/.config/nvim"
  if [[ -d "$nvim_config" ]] && [[ -f "$nvim_config/lazy-lock.json" || -f "$nvim_config/lazyvim.json" ]]; then
    log_skip "LazyVim config already exists"
    return 0
  fi

  # Only install if neovim is available
  if ! command_exists nvim; then
    log_warn "neovim not found, skipping LazyVim"
    return 1
  fi

  log_info "Installing LazyVim starter config..."
  # Backup existing config if any
  if [[ -d "$nvim_config" ]]; then
    mv "$nvim_config" "$nvim_config.bak.$(date +%s)"
  fi
  git clone https://github.com/LazyVim/starter "$nvim_config"
  rm -rf "$nvim_config/.git"
  log_ok "LazyVim installed"
}

install_fzf() {
  local fzf_dir="$HOME/.fzf"
  if [[ -d "$fzf_dir" ]]; then
    log_info "Updating fzf..."
    git -C "$fzf_dir" pull --quiet
    "$fzf_dir/install" --bin --no-bash --no-fish --no-update-rc
    log_ok "fzf updated"
  else
    log_info "Installing fzf from git..."
    git clone --depth 1 https://github.com/junegunn/fzf.git "$fzf_dir"
    "$fzf_dir/install" --all --no-bash --no-fish
    log_ok "fzf installed to $fzf_dir"
  fi
}

# === Main ===

main() {
  echo "========================================"
  echo "  Installing binary tools for Linux"
  echo "========================================"
  echo ""

  # Ensure ~/.local/bin exists and is in PATH
  mkdir -p "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$PATH"

  # Order matters: uv and bun are needed for later tools
  install_neovim
  install_uv
  install_bun

  # Tools with prebuilt binaries
  install_glow
  install_dua
  install_tlrc # installs cargo on ARM64 only (no prebuilt available)
  install_lazydocker
  install_fzf
  install_viu

  # Tools that depend on uv/bun
  install_thefuck
  install_ruff
  install_ty
  install_yt_dlp
  install_emojify
  install_opencode
  install_bash_language_server
  install_yaml_language_server

  # Optional: LazyVim (only if nvim config doesn't exist)
  # Uncomment if you want LazyVim on fresh installs:
  # install_lazyvim

  echo ""
  echo "========================================"
  echo "  Binary tools installation complete!"
  echo "========================================"
  echo ""
  echo "🔧 Make sure ~/.local/bin is in your PATH"
  echo "   Add to your shell config:"
  echo '   export PATH="$HOME/.local/bin:$PATH"'
}

main "$@"
