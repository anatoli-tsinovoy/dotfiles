#!/usr/bin/env bash
#
# Sourceable helper shared by volume.sh and volume_source.sh.
# Requires "$CONFIG_DIR/icons.sh" to have been sourced by the caller.

# Deadline (epoch seconds) until which volume_change must not reveal the slider.
SLIDER_SUPPRESS_FILE="/tmp/sketchybar_volume_slider.suppress"

# Name of the active output. Cheap enough for the switch-readback loop.
current_output_name() {
  SwitchAudioSource -t output -c
}

current_output_uid() {
  SwitchAudioSource -ct output -f json | jq -r ".uid"
}

# audio_output_icon <device-uid> -- bar icon for an output device.
audio_output_icon() {
  case "$1" in
  "BuiltInSpeakerDevice") printf '%s' "$SPEAKERS" ;;
  "BlackHole2ch_UID") printf '%s' "$BLACK_HOLE" ;;
  *) printf '%s' "$HEADPHONES" ;;
  esac
}

# The device popup is anchored to volume_source, so anything that changes the
# width of neighbouring items drags it sideways. Switching an output device makes
# the new device report its volume level, which fires volume_change ~0.5s later
# and would pop the slider open, then collapse it again 2s after that -- twice
# yanking the popup while the user is reading it.
#
# The popup's own drawing state can't be used to detect this: rebuilding the
# popup removes all of its children, which momentarily destroys it and reports
# 'null'. So the switcher stamps a deadline on disk instead, which is visible the
# instant it is written.

# suppress_slider <seconds>
suppress_slider() {
  printf '%s\n' "$(($(date +%s) + $1))" >"$SLIDER_SUPPRESS_FILE"
}

release_slider() {
  rm -f "$SLIDER_SUPPRESS_FILE"
}

slider_suppressed() {
  local deadline
  deadline="$(cat "$SLIDER_SUPPRESS_FILE" 2>/dev/null)" || return 1
  [ -n "$deadline" ] && [ "$(date +%s)" -lt "$deadline" ]
}

# Collapse the slider without animating, so the bar geometry settles in one step
# instead of sliding while the popup is visible.
collapse_slider_now() {
  sketchybar --set volume slider.width=0
}
