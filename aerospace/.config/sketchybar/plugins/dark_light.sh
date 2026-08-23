#!/usr/bin/env bash

detect_theme() {
  if defaults read -g AppleInterfaceStyle &>/dev/null; then
    # command succeeds and prints Dark
    echo "DARK"
  else
    # for light mode command fails and prints some odd error
    echo "LIGHT"
  fi
}

current_theme="$(detect_theme)"
previous_theme="$(sketchybar --query DARK_LIGHT | jq -r '.label.value')"
sketchybar --set DARK_LIGHT label="$current_theme" display=0
if [ "$SENDER" != "forced" ] && [ "$previous_theme" != "$current_theme" ]; then
  aerospace trigger-binding alt-shift-b --mode service
fi
