#!/usr/bin/env bash

volume_slider=(
  script="$PLUGIN_DIR/volume.sh"
  updates=on
  label.drawing=off
  icon.drawing=off
  slider.highlight_color=$BLUE
  slider.background.height=5
  slider.background.corner_radius=3
  slider.background.color=$BACKGROUND_2
  slider.knob=􀀁
  slider.knob.drawing=on
)

volume_source=(
  click_script="$PLUGIN_DIR/volume_source_click.sh"
  icon.color=$GREY
  icon.font="$FONT:Regular:14.0"
  label.width=24
  label.align=right
  label.font="$FONT:Regular:14.0"
  padding_right=0
)

volume_icon=(
  click_script="$PLUGIN_DIR/volume_click.sh"
  icon.color=$GREY
  icon.font="$FONT:Regular:14.0"
  label.width=24
  label.align=left
  label.font="$FONT:Regular:14.0"
  padding_left=0
)

sketchybar --add slider volume right \
  --set volume "${volume_slider[@]}" \
  --subscribe volume volume_change \
  mouse.clicked \
  --add item volume_icon right \
  --set volume_icon "${volume_icon[@]}" \
  --add item volume_source right \
  --set volume_source "${volume_source[@]}"
