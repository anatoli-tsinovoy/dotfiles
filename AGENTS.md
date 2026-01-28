# AGENTS.md - AI Agent Instructions for dotfiles Repository

Personal dotfiles for macOS and Linux using GNU Stow for symlink management.

## Quick Reference

```bash
# Bootstrap
./install.sh                            # Full setup (packages + stow)
./install.sh --force                    # Force: remove conflicting targets

# Verification (NO AUTOMATED TESTS)
bash -n script.sh                       # Syntax check bash
shellcheck script.sh                    # Lint bash (if installed)
zsh -n ~/.zshrc                         # Syntax check zsh after stow
stylua --check nvim/                    # Check lua formatting

# Container testing (recommended for Linux changes)
podman run -it -v ./:/root/dotfiles:ro python:3.13-slim bash
```

## Project Structure

```
dotfiles/
├── install.sh             # Entry point (packages + stow + oh-my-zsh)
├── Brewfile / Aptfile     # Package lists (macOS / Linux)
├── scripts/               # OS-specific setup (executed, NOT symlinked)
│   ├── linux/install-binaries.sh   # Binary tools (neovim, fzf, etc.)
│   └── macos/
│       ├── macos-defaults.sh       # System preferences
│       └── open-in-neovim/         # App: opens files in iTerm+Neovim
├── shims/                 # OS-specific stow packages (symlinked)
│   ├── linux/.local/bin/  # bat->batcat, fd->fdfind, node->bun
│   └── macos/.local/bin/  # docker->podman
├── git/                   # .gitconfig + .gitconfig.macos
├── nvim/                  # LazyVim-based Neovim config
├── zsh/                   # Unified zsh config (ORDER-SENSITIVE)
├── aerospace/             # Tiling WM + sketchybar (macOS only)
└── opencode/              # OpenCode AI configuration
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

## Common Patterns

### Adding a new tool (Linux)
1. Add to `Aptfile` if available via apt
2. Otherwise add install function to `scripts/linux/install-binaries.sh`
3. If binary name differs, add shim to `shims/linux/.local/bin/`

### Adding a new tool (macOS)
1. Add to `Brewfile` (brew or cask)
2. If podman-related, may need shim in `shims/macos/.local/bin/`

### Adding new dotfiles
1. Create package: `mkdir -p newpkg/.config/newpkg`
2. Add config files mirroring home structure
3. Add `run_stow -t ~ newpkg` to `install.sh`
4. Verify: `stow -n -t ~ newpkg` (dry-run)
