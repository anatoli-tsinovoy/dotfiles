# AGENTS.md - AI Agent Instructions for dotfiles Repository

Personal dotfiles for macOS and Linux using GNU Stow for symlink management.

## Project Structure

```
dotfiles/
├── bootstrap.sh           # Main setup script (entry point)
├── Brewfile / Aptfile     # Package lists (macOS / Linux)
├── shims/                  # OS-specific scripts and stow packages
│   ├── linux/
│   │   ├── .local/bin/         # Shims for Debian/Ubuntu naming
│   │   │   ├── bat             # batcat→bat shim
│   │   │   ├── fd              # fdfind→fd shim
│   │   │   └── node            # bun→node shim
│   │   └── install-binaries.sh # Binary tool installer
│   └── macos/
│       ├── .local/bin/docker   # podman→docker shim (stowed)
│       └── macos-defaults.sh   # System preferences script
├── git/                   # Git configuration
├── nvim/                  # Neovim config (LazyVim-based)
├── zsh/                   # Unified zsh config
│   ├── .zshrc             # Common config (ORDER-SENSITIVE!)
│   ├── .zshrc.macos       # macOS-specific post-init
│   └── .zshrc.linux       # Linux-specific post-init
├── aerospace/             # Tiling WM (macOS)
└── opencode/              # OpenCode AI config
```

## Commands

```bash
./bootstrap.sh                          # Full bootstrap (packages + stow)
./shims/macos/macos-defaults.sh         # macOS: system preferences
./shims/linux/install-binaries.sh       # Linux: binary tools

# Manual stow
stow -t ~ <package>                     # Link package to home
stow -t ~ -d shims <os>                 # Link OS-specific (linux/macos)
stow -D -t ~ <package>                  # Unlink package

# Verification
bash -n script.sh                       # Syntax check bash
zsh -n ~/.zshrc                         # Syntax check zsh
ls -la ~ | grep "^l"                    # Check symlinks
```

## No Tests - Verify By

1. Container test: `podman run -it -v ./:/root/dotfiles:ro python:3.13-slim bash`
2. Check symlinks after stow
3. Open new shell, verify prompt/aliases work

## Shell Script Style (bash/zsh)

```bash
#!/usr/bin/env bash
set -euo pipefail                       # ALWAYS at top

# Logging helpers (use emoji prefixes)
log_info() { echo "ℹ️  $*"; }
log_ok() { echo "✅ $*"; }
log_warn() { echo "⚠️  $*"; }
log_skip() { echo "⏭️  $*"; }

command_exists() { command -v "$1" &>/dev/null; }

# IDEMPOTENT pattern - always check before install
install_tool() {
  if command_exists tool; then
    log_skip "tool already installed"
    return 0
  fi
  log_info "Installing tool..."
  # ... install commands ...
  log_ok "tool installed"
}

# Root/sudo handling
run_privileged() {
  if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

# Platform detection
detect_os() {
  case "$(uname -s)" in
    Darwin) echo "mac" ;;
    Linux) echo "linux" ;;
    *) echo "other" ;;
  esac
}

is_inside_container() {
  [[ -f /.dockerenv ]] || [[ -n "${container:-}" ]] || \
    grep -qsE '(docker|kubepod)' /proc/1/cgroup 2>/dev/null
}

get_arch() {
  case "$(uname -m)" in
    x86_64) echo "x86_64" ;;
    aarch64|arm64) echo "aarch64" ;;
    *) echo "$(uname -m)" ;;
  esac
}
```

**Variable Quoting:** Always `"$var"`, `"$@"`. Use `${var:-default}` for defaults.

## Lua Style (Neovim)

2-space indent, 120 column width. LazyVim plugin format:
```lua
return {
  { "author/plugin-name", opts = { key = "value" } },
}
```

## Critical: zsh Config Order

The `.zshrc` is **order-sensitive**. Sections must execute in this sequence:

1. **PATH setup** - tools available for rest of config (shims in `~/.local/bin`)
2. **Oh My Zsh** - loads plugins
3. **Tool aliases** (bat theming, fzf preview)
4. **Vi-mode keybindings** - resets some bindings
5. **fzf keybindings** - MUST be after vi-mode or Tab breaks

OS-specific files sourced at END for post-init config only.

## Linux Binary Name Shims

Debian/Ubuntu uses different binary names. Handled via shims in `shims/linux/.local/bin/`:

```bash
# shims/linux/.local/bin/bat
#!/bin/sh
exec batcat "$@"

# shims/linux/.local/bin/fd  
#!/bin/sh
exec fdfind "$@"
```

Shims work in scripts AND interactive shells (unlike aliases).

## Stow Package Layout

Packages mirror home directory structure:
```
nvim/.config/nvim/init.lua  →  ~/.config/nvim/init.lua
zsh/.zshrc                  →  ~/.zshrc
```

**NEVER use `stow --adopt`** - overwrites repo files with target files.

## Key Conventions

| Item | Convention |
|------|------------|
| Git config | `git/.gitconfig` (shared) + `~/.gitconfig.local` (OS-specific, created by bootstrap) |
| Docker (macOS) | Uses podman; shim at `shims/macos/.local/bin/docker` |
| Neovim | LazyVim-based, Tokyonight theme |
| Shell | Powerlevel10k, vi-mode, zsh-syntax-highlighting, zsh-autosuggestions |

## File Types & Tools

| Type | Formatter | Notes |
|------|-----------|-------|
| `.sh` | - | shellcheck (manual), `bash -n` for syntax |
| `.lua` | stylua | 2-space, 120 cols |
| `.json/.jsonc` | prettier | Use `$schema` when available |
| `.toml` | - | Single quotes, `#` comments |

## Agent Rules

1. **No tests** - verify by inspection and container testing
2. **Edit in repo** - never edit `~/.config/` directly (they're symlinks)
3. **Cross-platform** - shared packages affect both OS
4. **Order matters** - especially in `.zshrc`
5. **Idempotency** - all install functions must be safe to run multiple times
6. **Container detection** - skip lazydocker/docker plugin when inside containers
