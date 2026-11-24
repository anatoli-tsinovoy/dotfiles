#!/usr/bin/env bash

SKETCHYBAR_DETECT_THEME=1 source "$CONFIG_DIR/colors.sh" # sets THEME

current_theme="$THEME"
previous_theme="$(sketchybar --query DARK_LIGHT | jq -r '.label.value')"
sketchybar --set DARK_LIGHT label="$current_theme" display=0
if [ "$SENDER" != "forced" ] && [ "$previous_theme" != "$current_theme" ]; then
  # sketchybar --reload # for some odd reason this increments the number of bars in play on every theme change
  # Note that this has a 10-second back-off time set by the crash-loop detection in sketchybar's plist, so fast-toggling is off the table
  launchctl kickstart -kp "gui/$UID/sh.brew.sketchybar"
fi
