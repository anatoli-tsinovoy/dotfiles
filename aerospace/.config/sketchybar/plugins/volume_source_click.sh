#!/usr/bin/env bash

HIDE_AFTER=5
TIMER_FILE="/tmp/sketchybar_volume_source.timer"

toggle_devices() {
  which SwitchAudioSource >/dev/null || exit 0
  source "$CONFIG_DIR/colors.sh"

  INITIAL_DRAWING="$(sketchybar --query "$NAME" | jq -r ".popup.drawing")"
  args=(--remove '/volume.device\.*/' --set "$NAME" popup.drawing=toggle)
  COUNTER=0
  CURRENT="$(SwitchAudioSource -t output -c)"
  while IFS= read -r device; do
    args+=(--add item volume.device.$COUNTER popup."$NAME"
      --set volume.device.$COUNTER label="${device}"
      click_script="SwitchAudioSource -s \"${device}\" && sketchybar --set $NAME popup.drawing=off")
    if [ "${device}" = "$CURRENT" ]; then
      args+=(label.color="$GREEN")
    fi

    COUNTER=$((COUNTER + 1))
  done <<<"$(SwitchAudioSource -a -t output)"

  sketchybar -m "${args[@]}" >/dev/null

  if [ "$INITIAL_DRAWING" = "off" ]; then
    auto_hide_devices
  fi
}

auto_hide_devices() {
  TIMER_TOKEN="$$-$(date +%s)"
  printf '%s\n' "$TIMER_TOKEN" >"$TIMER_FILE"

  sleep "$HIDE_AFTER"

  CURRENT_TOKEN="$(cat "$TIMER_FILE" 2>/dev/null || true)"
  if [ "$CURRENT_TOKEN" = "$TIMER_TOKEN" ]; then
    sketchybar --set "$NAME" popup.drawing=off
  fi
}

toggle_devices
