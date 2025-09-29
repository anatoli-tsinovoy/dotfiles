#!/usr/bin/env bash

source "$CONFIG_DIR/colors.sh"

# Read the plist data
plist_data=$(defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleSelectedInputSources)
current_input_source=$(echo "$plist_data" | plutil -convert xml1 -o - - | grep -A1 'KeyboardLayout Name' | tail -n1 | cut -d '>' -f2 | cut -d '<' -f1)
# current_input_source=$(defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleSelectedInputSources | awk -F'= ' '/KeyboardLayout Name/ {print $2}' | tr -d ';')

if [ $THEME = "LIGHT" ]; then
  A_ICON="􂏿"
  ALEPH_ICON="􂐉"
  QM_ICON="􀃬"
else
  A_ICON="􂐀"
  ALEPH_ICON="􂐊"
  QM_ICON="􀃭"
fi

if [ "$current_input_source" = "ABC" ]; then
  sketchybar --set input_source icon=$A_ICON
elif [ "$current_input_source" = "Hebrew" ]; then
  sketchybar --set input_source icon=$ALEPH_ICON
else
  sketchybar --set input_source icon=$QM_ICON
fi
