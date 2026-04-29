#!/usr/bin/env bash

WIDTH=100
HIDE_AFTER=2
TIMER_FILE="/tmp/sketchybar_volume_slider.timer"

detail_on() {
  sketchybar --animate tanh 30 --set volume slider.width=$WIDTH
}

detail_off() {
  sketchybar --animate tanh 30 --set volume slider.width=0
}

toggle_detail() {
  INITIAL_WIDTH=$(sketchybar --query volume | jq -r ".slider.width")
  if [ "$INITIAL_WIDTH" -eq "0" ]; then
    detail_on
    auto_hide_detail
  else
    detail_off
  fi
}

auto_hide_detail() {
  TIMER_TOKEN="$$-$(date +%s)"
  printf '%s\n' "$TIMER_TOKEN" >"$TIMER_FILE"

  sleep "$HIDE_AFTER"

  CURRENT_TOKEN="$(cat "$TIMER_FILE" 2>/dev/null || true)"
  if [ "$CURRENT_TOKEN" = "$TIMER_TOKEN" ]; then
    detail_off
  fi
}

toggle_detail
