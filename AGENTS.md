# AGENTS.md - AI Agent Instructions for dotfiles Repository

Personal dotfiles for macOS, Linux, and Termux using GNU Stow for symlink management.

## Quick Reference

```bash
# Bootstrap (detects OS automatically: mac, linux, termux)
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
├── install.sh             # Entry point (detects OS, installs packages, runs stow)
├── Brewfile               # macOS packages (Homebrew)
├── Aptfile                # Linux packages (apt via aptfile)
├── TermuxPkgfile          # Termux packages (pkg)
├── scripts/
│   ├── linux/install-binaries.sh   # Tools not in apt (neovim, fzf, bun, uv)
│   ├── termux/install-packages.sh  # Termux pkg installer
│   ├── macos/macos-defaults.sh     # macOS system preferences
│   └── tailscale-et.sh             # Tailscale + ET setup (mac/linux only)
├── shims/                 # OS-specific binary wrappers
│   ├── linux/.local/bin/  # bat fallback, fd→fdfind, node→bun
│   └── macos/.local/bin/  # docker→podman
├── termux/                # Termux-specific config
│   ├── .termux/           # colors.properties (light/dark themes)
│   └── .local/bin/        # termux-theme-toggle script
├── zsh/                   # Unified zsh config (ORDER-SENSITIVE)
├── nvim/                  # LazyVim-based Neovim config
├── git/                   # .gitconfig + .gitconfig.macos
├── aerospace/             # Tiling WM + sketchybar (macOS only)
├── iterm2/                # Dynamic iTerm2 profiles
└── opencode/              # OpenCode AI configuration
```

## Shell Script Style

```bash
#!/usr/bin/env bash
set -euo pipefail                       # ALWAYS at top

# Logging helpers (emoji prefixes)
log_info() { echo "ℹ️  $*"; }
log_ok() { echo "✅ $*"; }
log_skip() { echo "⏭️  $*"; }
log_warn() { echo "⚠️  $*"; }

command_exists() { command -v "$1" &>/dev/null; }

# IDEMPOTENT pattern - always check before install
install_tool() {
  command_exists tool && { log_skip "tool installed"; return 0; }
  log_info "Installing tool..." && log_ok "tool installed"
}

# Available helpers in install.sh / install-binaries.sh:
# - run_privileged: sudo wrapper (skips sudo if root)
# - detect_os: returns "mac", "linux", or "termux"
# - is_inside_container: true if in docker/podman
# - get_arch: returns "x86_64" or "aarch64"
# - get_github_release_version "owner/repo": fetches latest version
```

**Quoting:** Always `"$var"`, `"$@"`. Use `${var:-default}` for defaults.

## Critical: zsh Config Order

The `.zshrc` is **order-sensitive**. Sections must execute in sequence:

1. **PATH setup** - tools available for rest of config
2. **Termux config** - sourced BEFORE compinit (sets fpath for completions)
3. **Oh My Zsh + compinit** - loads plugins and completions
4. **Tool aliases** (bat theming, fzf preview)
5. **Vi-mode keybindings** - resets some bindings
6. **OS-specific config** - `.zshrc.macos`, `.zshrc.linux` sourced at END

**Termux detection:** `is_termux()` checks `$TERMUX_VERSION` or `$PREFIX` containing `com.termux`.

## Stow Package Layout

Packages mirror home directory structure:

```
nvim/.config/nvim/init.lua  →  ~/.config/nvim/init.lua
zsh/.zshrc                  →  ~/.zshrc
termux/.termux/colors.properties → ~/.termux/colors.properties
```

**NEVER use `stow --adopt`** - overwrites repo files with target files.

## OS-Specific Notes

| OS | Package Manager | Binary Names | Notes |
|----|-----------------|--------------|-------|
| macOS | Homebrew | upstream | Uses podman (docker shim provided) |
| Linux | apt + aptfile | bat, fdfind | Bat comes from GitHub release .deb; shims wrap remaining name mismatches |
| Termux | pkg | upstream | No sudo, no systemd, skips tailscale-et.sh |

**Termux detection must happen BEFORE Linux** in `detect_os()` because `uname -s` returns "Linux" on both.

## iTerm2 Dynamic Profiles

Profiles live in `iterm2/Library/Application Support/iTerm2/DynamicProfiles/` and stow to `~/Library/Application Support/iTerm2/DynamicProfiles/`.

- Use dynamic profiles for repo-managed iTerm2 profiles; they hot-reload when the folder contents change.
- Keep one profile per file (`Default.json`, `Btop.json`, etc.). Do not collapse full profiles into GUID-only entries in a shared `Profiles.json`.
- Keep `"Initial Text": ""` unless the profile is explicitly meant to type text into an interactive shell.
- Prefer `"Command"` + `"Custom Command": "Yes"` for startup behavior. This avoids leaking default-profile initial text into other profiles.
- After editing profiles, force a live refresh without restarting iTerm2:

```bash
profile_dir="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
for f in "$profile_dir"/*.json; do tmp="$f.tmp"; cp "$f" "$tmp" && mv "$tmp" "$f"; done
touch "$profile_dir"
```

- Validate with `python3 -m json.tool "$profile_dir/Default.json"`; `plutil -lint` rejects plain JSON here even though iTerm2 accepts it.

## Lua Style (Neovim)

2-space indent, 120 column width. LazyVim plugin format:

```lua
return {
  {
    "author/plugin-name",
    opts = { key = "value" },
  },
}
```

## File Types & Formatters

| Type | Formatter | Notes |
|------|-----------|-------|
| `.sh` | shfmt | shellcheck for linting, `bash -n` for syntax |
| `.lua` | stylua | 2-space indent, 120 cols |
| `.json/.jsonc` | prettier | Use `$schema` when available |
| `.toml` | - | Single quotes, `#` comments |

## Agent Rules

1. **No automated tests** - verify by syntax check and container testing
2. **Edit in repo** - never edit `~/.config/` directly (they're symlinks)
3. **Cross-platform** - changes to shared packages affect all 3 OS targets
4. **Order matters** - especially in `.zshrc` (Termux before compinit)
5. **Idempotency** - all install functions must be safe to run multiple times
6. **Container detection** - skip lazydocker/docker when inside containers
7. **No sudo on Termux** - use pkg directly, never run_privileged

## Common Patterns

### Adding a new tool (Linux)
1. Add to `Aptfile` if available via apt
2. Otherwise add install function to `scripts/linux/install-binaries.sh`
3. If binary name differs, add shim to `shims/linux/.local/bin/`

### Adding a new tool (macOS)
1. Add to `Brewfile` (brew or cask)
2. If podman-related, may need shim in `shims/macos/.local/bin/`

### Adding a new tool (Termux)
1. Add to `TermuxPkgfile` (one package per line)
2. Termux uses upstream binary names (no shims needed for bat/fd)

### Adding new dotfiles
1. Create package: `mkdir -p newpkg/.config/newpkg`
2. Add config files mirroring home structure
3. Add `run_stow -t ~ newpkg` to `install.sh`
4. Verify: `stow -n -t ~ newpkg` (dry-run)
