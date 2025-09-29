#!/usr/bin/env bash
source "$CONFIG_DIR/plugins/map_monitors.sh"
# Invisible watcher that stores the current connected displays state in its label.
# Create the invisible item and attach the plugin script
# TODO: There's actually no NSDistributedNotificationCenter notification for monitor changes, this is  all moot
sketchybar --add item DISPLAY_CHANGE right \
  --set DISPLAY_CHANGE script="$PLUGIN_DIR/display_changes.sh" display=0 updates=on label="$(map_monitors)" \
  --add event display_changed \
  --subscribe DISPLAY_CHANGE display_changed
