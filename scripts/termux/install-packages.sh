#!/usr/bin/env bash
# install-packages.sh - Install Termux packages from TermuxPkgfile
# Run inside Termux only. Never uses sudo.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
PKGFILE="$REPO_DIR/TermuxPkgfile"

# === Helper functions ===
log_info() { echo "ℹ️  $*"; }
log_ok() { echo "✅ $*"; }
log_skip() { echo "⏭️  $*"; }
log_warn() { echo "⚠️  $*"; }

command_exists() { command -v "$1" &>/dev/null; }

# === Main ===

main() {
  echo "========================================"
  echo "  Installing Termux packages"
  echo "========================================"
  echo ""

  if [[ ! -f "$PKGFILE" ]]; then
    log_warn "TermuxPkgfile not found at $PKGFILE"
    exit 1
  fi

  # Upgrade all packages first (fixes SSL/curl library issues)
  log_info "Upgrading all packages..."
  pkg upgrade -y
  log_ok "Packages upgraded"

  # Read packages from TermuxPkgfile (skip comments and empty lines)
  local packages=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    # Trim whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -n "$line" ]] && packages+=("$line")
  done < "$PKGFILE"

  if [[ ${#packages[@]} -eq 0 ]]; then
    log_warn "No packages found in TermuxPkgfile"
    exit 1
  fi

  log_info "Installing ${#packages[@]} packages..."

  # Install all packages in one command for efficiency
  pkg install -y "${packages[@]}"

  log_ok "All packages installed"

  echo ""
  echo "========================================"
  echo "  Termux packages installation complete!"
  echo "========================================"
}

main "$@"
