# AGENTS.md - AI Agent Instructions for dotfiles Repository

Personal dotfiles for macOS and Linux using GNU Stow for symlink management.

## Project Structure

```
dotfiles/
├── install.sh             # Main setup script (entry point)
├── Brewfile / Aptfile     # Package lists (macOS / Linux)
├── scripts/                # OS-specific setup scripts (executed, not symlinked)
│   ├── linux/
│   │   └── install-binaries.sh  # Binary tool installer (neovim, fzf, etc.)
│   └── macos/
│       └── macos-defaults.sh    # System preferences script
├── shims/                  # OS-specific stow packages (symlinked)
│   ├── linux/
│   │   └── .local/bin/          # Shims: bat→batcat, fd→fdfind, node→bun
│   └── macos/
│       └── .local/bin/docker    # podman→docker shim
├── git/                   # Git configuration (.gitconfig + .gitconfig.macos)
├── nvim/                  # Neovim config (LazyVim-based, Tokyonight)
├── zsh/                   # Unified zsh config (ORDER-SENSITIVE)
│   ├── .zshrc             # Common config
│   ├── .zshrc.macos       # macOS post-init
│   └── .zshrc.linux       # Linux post-init
├── aerospace/             # Tiling WM (macOS only)
└── opencode/              # OpenCode AI config
```

## Commands

```bash
./install.sh                            # Full bootstrap (packages + stow)
./scripts/macos/macos-defaults.sh       # macOS: system preferences
./scripts/linux/install-binaries.sh     # Linux: binary tools

# Manual stow
stow -t ~ <package>                     # Link package to home
stow -t ~ -d shims <os>                 # Link OS-specific (linux/macos)
stow -D -t ~ <package>                  # Unlink package

# Verification (NO AUTOMATED TESTS)
bash -n script.sh                       # Syntax check bash
zsh -n ~/.zshrc                         # Syntax check zsh
ls -la ~ | grep "^l"                    # Check symlinks
podman run -it -v ./:/root/dotfiles:ro python:3.13-slim bash  # Container test
```

## Shell Script Style

```bash
#!/usr/bin/env bash
set -euo pipefail                       # ALWAYS at top

# Logging: log_info, log_ok, log_warn, log_skip (emoji prefixes)
log_info() { echo "ℹ️  $*"; }
command_exists() { command -v "$1" &>/dev/null; }

# IDEMPOTENT pattern - always check before install
install_tool() {
  command_exists tool && { log_skip "tool installed"; return 0; }
  log_info "Installing tool..." && log_ok "tool installed"
}

# Helpers: run_privileged, detect_os, is_inside_container, get_arch
# See install.sh or scripts/linux/install-binaries.sh for implementations
```

**Quoting:** Always `"$var"`, `"$@"`. Use `${var:-default}` for defaults.

## Lua Style (Neovim)

2-space indent, 120 column width. LazyVim plugin format:

```lua
return {
  {
    "author/plugin-name",
    opts = {
      key = "value",
    },
  },
}
```

## Critical: zsh Config Order

The `.zshrc` is **order-sensitive**. Sections must execute in sequence:

1. **PATH setup** - tools available for rest of config (`~/.local/bin` shims)
2. **Oh My Zsh** - loads plugins
3. **Tool aliases** (bat theming, fzf preview)
4. **Vi-mode keybindings** - resets some bindings
5. **fzf keybindings** - MUST be after vi-mode or Tab breaks

OS-specific files (`.zshrc.macos`, `.zshrc.linux`) sourced at END.

## Stow Package Layout

Packages mirror home directory structure:

```
nvim/.config/nvim/init.lua  →  ~/.config/nvim/init.lua
zsh/.zshrc                  →  ~/.zshrc
```

**NEVER use `stow --adopt`** - overwrites repo files with target files.

## Linux Binary Name Shims

Debian/Ubuntu uses different binary names. Shims in `shims/linux/.local/bin/`:

```bash
# shims/linux/.local/bin/bat
#!/bin/sh
exec batcat "$@"
```

Shims work in scripts AND interactive shells (unlike aliases).

## File Types & Formatters

| Type | Formatter | Notes |
|------|-----------|-------|
| `.sh` | shfmt | shellcheck for linting, `bash -n` for syntax |
| `.lua` | stylua | 2-space indent, 120 cols |
| `.json/.jsonc` | prettier | Use `$schema` when available |
| `.toml` | - | Single quotes, `#` comments |

## Key Conventions

| Item | Convention |
|------|------------|
| Git config | `git/.gitconfig` (shared) + `~/.gitconfig.local` (OS-specific, created by install.sh) |
| Docker (macOS) | Uses podman; shim at `shims/macos/.local/bin/docker` |
| Neovim | LazyVim-based, Tokyonight theme (transparent) |
| Shell | Powerlevel10k, vi-mode, zsh-syntax-highlighting, zsh-autosuggestions |

## Agent Rules

1. **No automated tests** - verify by syntax check and container testing
2. **Edit in repo** - never edit `~/.config/` directly (they're symlinks)
3. **Cross-platform** - shared packages affect both macOS and Linux
4. **Order matters** - especially in `.zshrc`
5. **Idempotency** - all install functions must be safe to run multiple times
6. **Container detection** - skip lazydocker/docker plugin when inside containers
