#!/usr/bin/env bash
set -euo pipefail

ITEM="dark_light"

detect_theme() {
  if command -v osascript >/dev/null 2>&1; then
    if osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode' \
      2>/dev/null | grep -qi true; then
      echo "dark"; return
    fi
  fi
  if defaults read -g AppleInterfaceStyle 2>/dev/null | grep -qi Dark; then
    echo "dark"
  else
    echo "light"
  fi
}

current="$(detect_theme)"

# Read previously stored value from the item (tolerate early startup)
previous="$(sketchybar --query "$ITEM" 2>/dev/null | jq -r '.label.value // empty')"

# Always persist the current theme in the label
sketchybar --set "$ITEM" label="$current"

# Only reload on real appearance change and if value changed
if [ "${1:-${SENDER:-}}" = "appearance_changed" ] && [ "$previous" != "$current" ]; then
  sketchybar --reload
fi
