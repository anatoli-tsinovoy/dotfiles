#!/usr/bin/env bash

WIDTH=100
HIDE_AFTER=2
TIMER_FILE="/tmp/sketchybar_volume_slider.timer"

detail_on() {
  sketchybar --animate tanh 30 --set "$NAME" slider.width=$WIDTH
}

detail_off() {
  sketchybar --animate tanh 30 --set "$NAME" slider.width=0
}

reset_auto_hide_timer() {
  TIMER_TOKEN="$$-$(date +%s)"
  printf '%s\n' "$TIMER_TOKEN" >"$TIMER_FILE"
}

auto_hide_detail() {
  reset_auto_hide_timer

  sleep "$HIDE_AFTER"

  CURRENT_TOKEN="$(cat "$TIMER_FILE" 2>/dev/null || true)"
  if [ "$CURRENT_TOKEN" = "$TIMER_TOKEN" ]; then
    detail_off
  fi
}

volume_change() {
  source "$CONFIG_DIR/icons.sh"

  case $INFO in
  [6-9][0-9] | 100)
    ICON=$VOLUME_100
    ;;
  [3-5][0-9])
    ICON=$VOLUME_66
    ;;
  [1-2][0-9])
    ICON=$VOLUME_33
    ;;
  [1-9])
    ICON=$VOLUME_10
    ;;
  0)
    ICON=$VOLUME_0
    ;;
  *) ICON=$VOLUME_100 ;;
  esac

  # TODO: Store this as some property that's periodically updated instead of making an expensive call on every volume change
  CURRENT_OUTPUT_UID="$(SwitchAudioSource -ct output -f json | jq -r ".uid")"
  case "$CURRENT_OUTPUT_UID" in
  "BuiltInSpeakerDevice")
    OUTPUT_ICON=$SPEAKERS
    ;;
  "BlackHole2ch_UID")
    OUTPUT_ICON=$BLACK_HOLE
    ;;
  *)
    OUTPUT_ICON=$HEADPHONES
    ;;
  esac

  sketchybar --set volume_source label="$OUTPUT_ICON" \
    --set volume_icon label="$ICON" \
    --set "$NAME" slider.percentage=$INFO

  INITIAL_WIDTH="$(sketchybar --query "$NAME" | jq -r ".slider.width")"
  if [ "$INITIAL_WIDTH" -eq "0" ]; then
    detail_on
  fi

  auto_hide_detail
}

mouse_clicked() {
  osascript -e "set volume output volume $PERCENTAGE"
  auto_hide_detail
}

mouse_entered() {
  reset_auto_hide_timer
}

mouse_exited() {
  auto_hide_detail
}

case "$SENDER" in
"volume_change")
  volume_change
  ;;
"mouse.clicked")
  mouse_clicked
  ;;
"mouse.entered")
  mouse_entered
  ;;
"mouse.exited")
  mouse_exited
  ;;
esac
