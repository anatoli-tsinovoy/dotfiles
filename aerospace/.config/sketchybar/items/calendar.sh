#!/usr/bin/env bash

calendar=(
  # icon=􀐫
  # icon.font="$FONT:Black:12.0"
  # icon.padding_right=0
  label.align=right
  padding_right=10
  padding_left=15
  update_freq=30
  script="$PLUGIN_DIR/calendar.sh"
  click_script="$PLUGIN_DIR/notification_center.sh"
)

sketchybar --add item calendar right \
  --set calendar "${calendar[@]}" \
  --subscribe calendar system_woke
