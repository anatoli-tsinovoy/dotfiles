#!/usr/bin/env bash
source "$CONFIG_DIR/plugins/map_monitors.sh"
sleep 1
current_displays="$(map_monitors)"
previous_displays="$(sketchybar --query DISPLAY_CHANGE | jq -r '.label.value')"
sketchybar --set DISPLAY_CHANGE label="$current_displays" display=0

if [ "$previous_displays" != "$current_displays" ]; then
  sketchybar --trigger aerospace_focus_change
fi
