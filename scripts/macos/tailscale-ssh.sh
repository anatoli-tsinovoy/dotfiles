#!/usr/bin/env bash
#
# Tailscale SSH and Eternal Terminal setup for macOS
#
# This script enables remote SSH access via Tailscale network.
# Only run if you want this machine accessible over Tailscale SSH.
#
# SECURITY WARNING:
# - Tailscale SSH exposes this machine to your tailnet
# - ET (Eternal Terminal) allows persistent remote sessions
# - Both run as root services
#
set -euo pipefail

log_info() { echo "ℹ️  $*"; }
log_ok() { echo "✅ $*"; }
log_warn() { echo "⚠️  $*"; }
log_skip() { echo "⏭️  $*"; }

command_exists() { command -v "$1" &>/dev/null; }

run_privileged() {
  if [[ $EUID -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  log_warn "This script is for macOS only"
  exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║          Tailscale SSH & Eternal Terminal Setup                  ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║  This will:                                                      ║"
echo "║  • Start tailscale service (sudo)                                ║"
echo "║  • Run 'tailscale up' to connect to your tailnet                 ║"
echo "║  • Start ET (Eternal Terminal) service (sudo)                    ║"
echo "║                                                                  ║"
echo "║  SECURITY: This exposes your machine to your tailnet for SSH    ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
read -rp "Do you want to proceed? [y/N] " response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
  log_skip "Skipped Tailscale SSH setup"
  exit 0
fi

###############################################################################
# Tailscale Setup
###############################################################################

if ! command_exists tailscale; then
  log_warn "tailscale not found. Install with: brew install tailscale"
  exit 1
fi

# Create isolated bin directory with only etterminal symlink (minimal attack surface)
ET_BIN_DIR="/usr/local/et-bin"
HOMEBREW_ETTERMINAL="/opt/homebrew/bin/etterminal"

if [[ -x "$HOMEBREW_ETTERMINAL" ]]; then
  run_privileged mkdir -p "$ET_BIN_DIR"
  run_privileged ln -sf "$HOMEBREW_ETTERMINAL" "$ET_BIN_DIR/etterminal"
  log_ok "etterminal symlink created in $ET_BIN_DIR"
fi

log_info "Starting tailscale service..."
run_privileged brew services start tailscale

log_info "Connecting to tailnet (this may open a browser for auth)..."
run_privileged tailscale up

log_ok "Tailscale connected"

###############################################################################
# Eternal Terminal Setup
###############################################################################

if ! command_exists etserver; then
  log_warn "ET not found. Install with: brew install mistertea/et/et"
  exit 1
fi

log_info "Starting ET service..."
run_privileged brew services start mistertea/et/et

log_ok "ET (Eternal Terminal) configured"

###############################################################################
# Summary
###############################################################################

echo ""
echo "══════════════════════════════════════════════════════════════════"
echo "  Setup complete!"
echo ""
echo "  Tailscale status:  tailscale status"
echo "  ET service status: sudo brew services list | grep et"
echo ""
echo "  To connect from another machine:"
echo "    et <your-tailscale-hostname>"
echo "══════════════════════════════════════════════════════════════════"
