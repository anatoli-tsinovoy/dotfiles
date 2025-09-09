#!/bin/bash

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
  # sketchybar --reload # for some odd reason this increments the number of bars in play on every theme change
  # Note that this has a 10-second back-off time set by the crash-loop detection in sketchybar's plist, so fast-toggling is off the table
  launchctl kickstart -kp "gui/$UID/homebrew.mxcl.sketchybar"
fi
