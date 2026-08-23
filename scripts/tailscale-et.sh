#!/usr/bin/env bash
#
# Tailscale + Eternal Terminal (ET) remote access setup
# Supports: macOS (Tailscale Standalone + native sshd, ET via brew) and Linux (systemd)
#
# Tailscale: VPN mesh network for secure connectivity
# ET: Persistent terminal sessions that survive network interruptions
#
# SECURITY WARNING: Both services run as root and expose this machine to your tailnet
#
set -euo pipefail

log_info() { echo "ℹ️  $*"; }
log_ok() { echo "✅ $*"; }
log_warn() { echo "⚠️  $*"; }
log_skip() { echo "⏭️  $*"; }

command_exists() { command -v "$1" &>/dev/null; }

is_inside_container() {
  [[ -f /.dockerenv ]] || [[ -n "${container:-}" ]] || grep -q docker /proc/1/cgroup 2>/dev/null
}

has_systemd() {
  [[ -d /run/systemd/system ]]
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

OS="$(detect_os)"

if [[ "$OS" == "other" ]]; then
  log_warn "This script only supports macOS and Linux"
  exit 1
fi

if is_inside_container && ! has_systemd; then
  log_skip "Inside container without systemd, skipping Tailscale + ET setup"
  exit 0
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║          Tailscale + Eternal Terminal Setup                      ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║  This will:                                                      ║"
if [[ "$OS" == "mac" ]]; then
  echo "║  • Use the installed Tailscale Standalone app                    ║"
  echo "║  • Start ET (Eternal Terminal) service (sudo)                    ║"
else
  echo "║  • Start tailscale service (sudo)                                ║"
  echo "║  • Run 'tailscale up' to connect to your tailnet                 ║"
  echo "║  • Start ET (Eternal Terminal) service (sudo)                    ║"
fi
echo "║                                                                  ║"
echo "║  SECURITY: This exposes your machine to your tailnet for SSH    ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
read -rp "Do you want to proceed? [y/N] " response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
  log_skip "Skipped Tailscale + ET setup"
  exit 0
fi

###############################################################################
# Tailscale Setup
###############################################################################

if [[ "$OS" == "mac" ]]; then
  TAILSCALE_APP="/Applications/Tailscale.app"
  if ! brew list --cask tailscale-app &>/dev/null || [[ ! -d "$TAILSCALE_APP" ]]; then
    log_warn "Tailscale Standalone not found. Install it with: brew install --cask tailscale-app"
    exit 1
  fi
  log_info "Opening Tailscale Standalone..."
  open -a "$TAILSCALE_APP"
  log_info "Complete Tailscale login or system-extension approval in the GUI if prompted."
else
  if ! command_exists tailscale; then
    log_warn "tailscale not found. Install with: curl -fsSL https://tailscale.com/install.sh | sh"
    exit 1
  fi
fi

if [[ "$OS" == "mac" ]]; then
  ET_BIN_DIR="/usr/local/et-bin"
  ETTERMINAL_PATH="/opt/homebrew/bin/etterminal"
  if [[ -x "$ETTERMINAL_PATH" ]]; then
    run_privileged mkdir -p "$ET_BIN_DIR"
    run_privileged ln -sf "$ETTERMINAL_PATH" "$ET_BIN_DIR/etterminal"
    log_ok "etterminal symlink created in $ET_BIN_DIR"
  fi
fi

if [[ "$OS" == "linux" ]]; then
  log_info "Starting tailscale service..."
  run_privileged systemctl enable --now tailscaled

  log_info "Connecting to tailnet (this may open a browser for auth)..."
  run_privileged tailscale up

  log_ok "Tailscale connected"
fi

###############################################################################
# Eternal Terminal Setup
###############################################################################

if ! command_exists etserver; then
  if [[ "$OS" == "mac" ]]; then
    log_warn "ET not found. Install with: brew install mistertea/et/et"
  else
    log_warn "ET not found. Install with:"
    log_warn "  Ubuntu: sudo add-apt-repository ppa:jgmath2000/et && sudo apt install et"
    log_warn "  Debian: See https://eternalterminal.dev/download/"
  fi
  exit 1
fi

log_info "Starting ET service..."
if [[ "$OS" == "mac" ]]; then
  run_privileged brew services start mistertea/et/et
else
  run_privileged systemctl enable --now et
fi

log_ok "ET (Eternal Terminal) configured"

###############################################################################
# Summary
###############################################################################

echo ""
echo "══════════════════════════════════════════════════════════════════"
echo "  Setup complete!"
echo ""
if [[ "$OS" == "mac" ]]; then
  echo "  Tailscale: official Standalone app"
  echo "  Tailscale status:  tailscale status (after GUI login)"
  echo "  ET service status: sudo brew services list | grep et"
else
  echo "  Tailscale status:  tailscale status"
  echo "  ET service status: systemctl status et"
fi
echo ""
echo "  To connect from another machine:"
echo "    et <your-tailscale-hostname>"
echo "══════════════════════════════════════════════════════════════════"
