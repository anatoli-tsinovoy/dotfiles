#!/usr/bin/env bash

# Invisible watcher that stores the current theme in its label.
ITEM_NAME="dark_light"

# Create the invisible item and attach the plugin script
sketchybar --add item "$ITEM_NAME" right \
           --set "$ITEM_NAME" display=0 script="$PLUGIN_DIR/dark-light.sh"

# Initialize stored value on cold start (no reload on init)
"$PLUGIN_DIR/dark-light.sh" init

# Subscribe to macOS appearance changes
sketchybar --subscribe "$ITEM_NAME" appearance_changed
