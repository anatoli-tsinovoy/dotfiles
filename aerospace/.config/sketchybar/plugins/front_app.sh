#!/usr/bin/env bash

# Some events send additional information specific to the event in the $INFO
# variable. E.g. the front_app_switched event sends the name of the newly
# focused application in the $INFO variable:
# https://felixkratz.github.io/SketchyBar/config/events#events-and-scripting

# AEROSPACE_FOCUSED_MONITOR_NO=$(aerospace list-workspaces --focused)
# AEROSPACE_LIST_OF_WINDOWS_IN_FOCUSED_MONITOR=$(aerospace list-windows --workspace $AEROSPACE_FOCUSED_MONITOR_NO | awk -F'|' '{gsub(/^ *| *$/, "", $2); print $2}')

if [ "$SENDER" = "front_app_switched" ]; then
  app_icon="app.$INFO"
  # SecurityAgent has no app icon; use macOS's native keychain artwork.
  if [ "$INFO" = "SecurityAgent" ]; then
    app_icon="app.com.apple.keychainaccess"
  fi
  sketchybar --set "$NAME" label="$INFO" icon.background.image="$app_icon" icon.background.image.scale=0.8
fi
