#!/usr/bin/env bash
set -euo pipefail

# Toggle Notification Center with its "Show Notification Center" shortcut
# (Ctrl+Option+Cmd+Shift+N), which scripts/macos/macos-defaults.sh binds; the
# binding takes effect at the next login. Accessibility presses on the menu bar
# clock stopped working in macOS 27: the drawer opens and is dismissed ~0.3s
# later.
osascript -e 'tell application "System Events" to key code 45 using {control down, option down, command down, shift down}'
