#!/bin/bash

sketchybar --add item input_source right \
  --set input_source \
  icon.font="$FONT:Regular:20.0" \
  script="$PLUGIN_DIR/get_input_source.sh" \
  icon.color=0xffffffff \
  --add event input_source_changed com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged \
  --subscribe input_source input_source_changed
