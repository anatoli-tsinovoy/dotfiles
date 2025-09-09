#!/bin/bash

# Invisible watcher that stores the current theme in its label.
# Create the invisible item and attach the plugin script
sketchybar --add item DARK_LIGHT right \
  --set DARK_LIGHT script="$PLUGIN_DIR/dark_light.sh" display=0 updates=on \
  --add event appearance_changed AppleInterfaceThemeChangedNotification \
  --subscribe DARK_LIGHT appearance_changed
