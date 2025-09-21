# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Architecture Overview

This is a **macOS-focused dotfiles repository** using GNU Stow for symlink management and organized around different application/tool categories. The repository follows a modular structure where each directory represents a "stow package" that gets symlinked to the home directory.

### Key Components

**Core Configuration Systems:**
- **Aerospace**: Window manager configuration with custom SketchyBar integration
- **Zsh + Oh-My-Zsh**: Terminal setup with Powerlevel10k theme, custom plugins, and Cursor terminal detection
- **Git**: Enhanced Git configuration with delta pager, histogram diff algorithm, and helpful aliases
- **Neovim**: Basic vim configuration focused on essential settings
- **iTerm2**: Terminal application preferences and profiles
- **Cursor**: Code editor CLI configuration with vim mode and privacy settings
- **Warp**: Terminal application with custom themes (Simply Light/Dark)

**SketchyBar Integration:**
The aerospace directory contains a sophisticated SketchyBar setup that integrates with the Aerospace window manager. It includes custom plugins for system monitoring (CPU, battery, volume), workspace management, and visual enhancements. The setup uses a helper process and custom shell scripts for real-time updates.

**Stow-Based Management:**
Each top-level directory (except for root config files) is a Stow package that mirrors the target directory structure. The `.stow-local-ignore` file excludes certain files from being symlinked.

## Common Development Commands

### Initial Setup
```bash
# Bootstrap the entire system (run once)
./bootstrap.sh

# Manual stow operations for specific packages
stow -t ~ nvim git
stow -t ~ aerospace iterm2 cursor-macos warp-macos  # macOS specific
stow -t ~ zsh-macos  # macOS zsh setup
```

### Maintenance and Updates
```bash
# Update git submodules (oh-my-zsh plugins and themes)
git submodule update --init --recursive

# Refresh system configurations (aerospace service mode)
# Use Alt+Shift+; then Esc to reload aerospace and refresh SketchyBar
```

### Homebrew Package Management
```bash
# Install/update all packages from Brewfile
brew bundle --file=Brewfile

# Generate/update Brewfile from current installations
brew bundle dump --file=Brewfile --force
```

### SketchyBar Development
```bash
# Restart SketchyBar service
brew services restart sketchybar

# Rebuild helper process (when modifying SketchyBar plugins)
cd aerospace/.config/sketchybar/helper && make
```

### Testing and Validation
```bash
# Test stow operations without actually linking
stow -n -t ~ <package_name>

# Check for conflicts before stowing
stow -t ~ --conflicts <package_name>

# Verify zsh configuration loads properly
zsh -n ~/.zshrc
```

## Architecture Notes

**Cursor Terminal Detection:** The zsh configuration includes logic to detect when running in Cursor's integrated terminal and adjusts the prompt theme accordingly (Powerlevel10k vs robbyrussell).

**Aerospace + SketchyBar Integration:** The window manager setup includes workspace change triggers, focus change events, and monitor management. SketchyBar plugins are tightly integrated with aerospace events for real-time status updates.

**Modular Stow Structure:** Each directory represents a logical grouping of configurations that can be independently managed. This allows for platform-specific packages (e.g., `zsh-macos` vs potential `zsh-linux`).

**Git Submodules:** External oh-my-zsh plugins and themes are managed as git submodules, allowing for easy updates while maintaining version control.