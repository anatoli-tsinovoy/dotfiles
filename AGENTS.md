# AGENTS.md - AI Agent Instructions for dotfiles Repository

## Repository Overview

Personal dotfiles repository for macOS and Linux using GNU Stow for symlink management.
Cross-platform configuration for zsh, neovim, git, aerospace (tiling WM), and sketchybar.

## Project Structure

```
dotfiles/
├── bootstrap.sh           # Main setup script (entry point)
├── install-binaries.sh    # Linux binary tool installer
├── macos-defaults.sh      # macOS system preferences
├── docker-shim.sh         # Podman-to-Docker compatibility shim
├── Brewfile               # macOS Homebrew packages
├── Aptfile                # Linux apt packages
├── .stow-local-ignore     # Files excluded from stow linking
├── git/                   # Git configuration (cross-platform)
├── nvim/                  # Neovim config (LazyVim-based)
├── opencode/              # OpenCode AI config
├── zsh/                   # Unified zsh config (cross-platform)
│   ├── .zshrc             # Common config (order-sensitive!)
│   ├── .zshrc.macos       # macOS-specific (Homebrew, podman, NVM)
│   ├── .zshrc.linux       # Linux-specific (minimal, post-init only)
│   └── .p10k.zsh          # Powerlevel10k theme config
├── aerospace/             # Aerospace tiling WM + sketchybar
├── cursor-macos/          # Cursor IDE settings
├── iterm2/                # iTerm2 profiles
├── warp-macos/            # Warp terminal config
└── termcolors/            # Color schemes (not stowed)
```

## Build/Setup Commands

```bash
./bootstrap.sh                    # Full bootstrap (packages + stow)
./macos-defaults.sh               # macOS-only: system preferences
./install-binaries.sh             # Linux-only: binary tools

# Manual stow (do NOT use --adopt, it overwrites repo files!)
stow -t ~ <package>               # Link package to home
stow -D -t ~ <package>            # Unlink package
stow --restow -t ~ <package>      # Re-link after changes
```

## No Tests

Verify changes by:
1. Running `bootstrap.sh` in a container: `podman run -it -v ./:/root/dotfiles:ro python:3.13-slim bash`
2. Checking symlinks: `ls -la ~ | grep "->"`
3. Opening a new shell and verifying prompt/aliases work

## Code Style Guidelines

### Shell Scripts (bash/zsh)

```bash
#!/usr/bin/env bash
set -euo pipefail    # ALWAYS at top

log_info() { echo "ℹ️  $*"; }
log_ok() { echo "✅ $*"; }
log_warn() { echo "⚠️  $*"; }
log_skip() { echo "⏭️  $*"; }

command_exists() { command -v "$1" &>/dev/null; }

# Idempotent pattern - check before install
install_tool() {
  if command_exists tool; then
    log_skip "tool already installed"
    return 0
  fi
  log_info "Installing tool..."
  # install commands
  log_ok "tool installed"
}

# Root/sudo handling
run_privileged() {
  if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

# Architecture detection
get_arch() {
  case "$(uname -m)" in
    x86_64) echo "x86_64" ;;
    aarch64|arm64) echo "aarch64" ;;
    *) echo "$(uname -m)" ;;
  esac
}
```

**Variable Quoting:** Always `"$var"`, `"$@"`. Use `${var:-default}` for defaults.

### Lua (Neovim)

Uses StyLua: 2-space indent, 120 column width, spaces not tabs.

```lua
return {
  { "author/plugin-name", opts = { ... } },
}
```

### TOML/JSON

- TOML: single quotes, `#` comments
- JSON/JSONC: 2-space indent, use `$schema` when available

## Critical: zsh Config Order

The `.zshrc` file is **order-sensitive**. Key sections must execute in this sequence:

1. **PATH setup** (early) - so tools are available
2. **Linux aliases** (fd→fdfind, bat→batcat) - before bat alias uses them
3. **Oh My Zsh** - loads plugins
4. **Tool aliases** (bat theming, fzf preview) - after base commands exist
5. **Vi-mode keybindings** - resets some bindings
6. **fzf keybindings** - MUST be after vi-mode or Tab completion breaks

OS-specific files (`.zshrc.linux`, `.zshrc.macos`) are sourced at the END for post-init config only.

## Platform Patterns

```bash
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
```

### Linux Binary Name Differences

```bash
# In .zshrc, set _bat_cmd variable BEFORE bat alias
if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
  _bat_cmd="batcat"
fi
: ${_bat_cmd:=bat}
alias bat="$_bat_cmd --color=always ..."
```

## Stow Package Layout

Each package mirrors home directory structure:
```
nvim/.config/nvim/init.lua  →  ~/.config/nvim/init.lua
zsh/.zshrc                  →  ~/.zshrc
```

**NEVER use `stow --adopt`** - it overwrites repo files with target files.

## Key Conventions

- **Git config:** `git/.gitconfig` (shared) + `~/.gitconfig.local` (OS-specific, created by bootstrap)
- **Oh My Zsh:** Powerlevel10k theme, vi-mode, zsh-syntax-highlighting, zsh-autosuggestions
- **Docker on macOS:** Uses podman; `docker-shim.sh` provides `docker` command
- **Neovim:** LazyVim-based config

## File Modification Guidelines

| File Type | Formatter | Linter |
|-----------|-----------|--------|
| `.sh` | - | shellcheck (manual) |
| `.lua` | stylua | - |
| `.json/.jsonc` | prettier | - |

## Quick Reference

```bash
ls -la ~ | grep "^l"              # Verify stow links
zsh -n ~/.zshrc                   # Syntax check zsh config
bash -n script.sh                 # Syntax check bash script
aerospace reload-config           # Reload aerospace (macOS)
```

## Important Notes for AI Agents

1. **No tests** - verify by inspection and container testing
2. **Edit in repo** - never edit files in `~/.config/` directly
3. **Cross-platform** - changes to shared packages affect both OS
4. **Order matters** - especially in `.zshrc` (see Critical section above)
5. **Idempotency** - all install functions must be safe to run multiple times
6. **Container detection** - skip container-only tools (lazydocker, docker plugin) when inside containers
