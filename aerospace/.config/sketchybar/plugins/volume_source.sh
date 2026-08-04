#!/usr/bin/env bash
#
# Audio output device switcher backing the sketchybar `volume_source` item.
#
# Usage: volume_source.sh [toggle|next|prev|select <device>]
#   toggle          click handler: show/hide the device popup
#   next|prev       walk the highlight through the output devices
#   select <device> switch to <device>, then hide the popup
#
# next/prev are built for being pressed repeatedly to walk to a device several
# entries away. Each press moves the highlighted entry immediately and cheaply;
# the CoreAudio switch is committed once, DEBOUNCE seconds after the last press.
#
# Switching on every press instead would cost ~0.75s each, so presses queue and
# the menu lags behind the keyboard -- and it would drag every audio app through
# each device passed in transit.
#
# They need no sketchybar-provided environment, so they work from a keybinding
# (see aerospace.toml).

ITEM="volume_source"
HIDE_AFTER=5
DEBOUNCE=0.35
DEADLINE_FILE="/tmp/sketchybar_volume_source.deadline"
PENDING_FILE="/tmp/sketchybar_volume_source.pending"
DEVICES_CACHE="/tmp/sketchybar_volume_source.devices"
LIST_CACHE="/tmp/sketchybar_volume_source.list.json"
LOCK_DIR="/tmp/sketchybar_volume_source.lock"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
SELF="$CONFIG_DIR/plugins/volume_source.sh"

# AeroSpace's exec environment may not carry Homebrew's bin dir, and
# sketchybar-msg aborts without $USER.
PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export USER="${USER:-$(id -un)}"

command -v SwitchAudioSource >/dev/null || exit 0
source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"
source "$CONFIG_DIR/plugins/volume_common.sh"

DEVICE_NAMES=()
DEVICE_UIDS=()

# Key repeat outpaces this script, so guard the read-modify-write of the pending
# selection. Without it concurrent presses all read the same base device and
# compute the same target, and their popup rebuilds interleave and blink the menu.
acquire_lock() {
  local holder unnamed=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    holder="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
    if [ -n "$holder" ]; then
      # Reap a lock orphaned by a killed invocation, but never steal from a live
      # holder: any fixed timeout would eventually fire under a long queue of
      # presses and hand out the lock twice.
      if kill -0 "$holder" 2>/dev/null; then
        unnamed=0
      else
        rm -rf "$LOCK_DIR"
        continue
      fi
    elif [ "$unnamed" -gt 40 ]; then
      # Holder died between mkdir and writing its pid.
      rm -rf "$LOCK_DIR"
      continue
    else
      unnamed=$((unnamed + 1))
    fi
    sleep 0.05
  done
  printf '%s\n' "$$" >"$LOCK_DIR/pid"
  trap 'rm -rf "$LOCK_DIR"' EXIT
}

release_lock() {
  trap - EXIT
  rm -rf "$LOCK_DIR"
}

# One CoreAudio enumeration gives both the popup labels and the UIDs the bar icon
# is keyed off, so nothing needs a second query per device.
#
# load_devices [reuse] -- 'reuse' takes the list cached by the press that started
# the current walk. Enumerating costs ~0.3s, which is slower than key repeat, so
# re-reading it per press would make the highlight visibly trail the keyboard.
# Staleness is bounded to a single walk; the commit always re-enumerates.
load_devices() {
  local json line
  if [ "${1:-}" = "reuse" ] && [ -s "$LIST_CACHE" ]; then
    json="$(cat "$LIST_CACHE")"
  else
    json="$(SwitchAudioSource -a -t output -f json)" || return 1
    printf '%s\n' "$json" >"$LIST_CACHE"
  fi
  DEVICE_NAMES=()
  DEVICE_UIDS=()
  while IFS= read -r line; do DEVICE_NAMES+=("$line"); done <<<"$(printf '%s\n' "$json" | jq -r ".name")"
  while IFS= read -r line; do DEVICE_UIDS+=("$line"); done <<<"$(printf '%s\n' "$json" | jq -r ".uid")"
}

# device_index <name> -- prints its position in DEVICE_NAMES.
device_index() {
  local target="$1" i
  for i in "${!DEVICE_NAMES[@]}"; do
    if [ "${DEVICE_NAMES[$i]}" = "$target" ]; then
      printf '%s' "$i"
      return 0
    fi
  done
  return 1
}

uid_for() {
  local i
  i="$(device_index "$1")" || return 1
  printf '%s' "${DEVICE_UIDS[$i]}"
}

# render <popup.drawing value> <highlighted device>
#
# Rebuilds the popup only when the device list itself changed. Re-adding items on
# every press would blink the menu, because a popup left with no children is
# destroyed and redrawn.
render() {
  local drawing="$1" highlight="$2" counter=0 device color list_key cached rebuild args=()

  list_key="$(printf '%s\n' "${DEVICE_NAMES[@]}")"
  cached="$(cat "$DEVICES_CACHE" 2>/dev/null || true)"
  if [ "$list_key" = "$cached" ] && sketchybar --query volume.device.0 >/dev/null 2>&1; then
    rebuild=0
  else
    rebuild=1
  fi

  args=(--set "$ITEM" popup.drawing="$drawing" label="$(audio_output_icon "$(uid_for "$highlight")")")
  if [ "$rebuild" -eq 1 ]; then
    args+=(--remove '/volume\.device\..*/')
  fi

  for device in "${DEVICE_NAMES[@]}"; do
    if [ "$device" = "$highlight" ]; then
      color="$GREEN"
    else
      color="$LABEL_COLOR"
    fi
    if [ "$rebuild" -eq 1 ]; then
      args+=(--add item "volume.device.$counter" popup."$ITEM"
        --set "volume.device.$counter" click_script="\"$SELF\" select \"$device\"")
    fi
    args+=(--set "volume.device.$counter" label="$device" label.color="$color")
    counter=$((counter + 1))
  done

  sketchybar -m "${args[@]}" >/dev/null

  if [ "$rebuild" -eq 1 ]; then
    printf '%s\n' "$list_key" >"$DEVICES_CACHE"
  fi
}

# Hides the popup HIDE_AFTER seconds after the *last* press. Every invocation
# pushes the deadline out; waiters that wake early see it moved and bow out, so
# the menu never closes mid-walk regardless of completion order.
auto_hide_devices() {
  printf '%s\n' "$(($(date +%s) + HIDE_AFTER))" >"$DEADLINE_FILE"

  sleep "$HIDE_AFTER"

  if [ "$(date +%s)" -ge "$(cat "$DEADLINE_FILE" 2>/dev/null || echo 0)" ]; then
    sketchybar --set "$ITEM" popup.drawing=off
    release_slider
  fi
}

# switch_to <device> <step> -- prints the device actually selected.
#
# Some entries CoreAudio advertises can't be made the default output at all:
# ZoomAudioDevice with Zoom not running, a display's audio while it sleeps.
# SwitchAudioSource still exits 0 for those, so read the selection back and keep
# stepping past the duds -- otherwise one of them traps the walk.
switch_to() {
  local target="$1" step="$2"
  local count=${#DEVICE_NAMES[@]} index attempt candidate

  index="$(device_index "$target")" || index=0

  for attempt in $(seq 0 $((count - 1))); do
    candidate="${DEVICE_NAMES[$(((index + (step * attempt) + (count * attempt)) % count))]}"
    SwitchAudioSource -s "$candidate" >/dev/null
    if [ "$(current_output_name)" = "$candidate" ]; then
      printf '%s' "$candidate"
      return 0
    fi
  done

  current_output_name
  return 1
}

# commit_pending <serial> -- applies the walk once the presses stop.
commit_pending() {
  local mine="$1" serial step target landed

  sleep "$DEBOUNCE"

  acquire_lock
  serial="$(sed -n 1p "$PENDING_FILE" 2>/dev/null || true)"
  if [ "$serial" != "$mine" ]; then
    # A newer press superseded this one; it owns the commit.
    release_lock
    return 0
  fi
  step="$(sed -n 2p "$PENDING_FILE")"
  target="$(sed -n 3p "$PENDING_FILE")"
  rm -f "$PENDING_FILE"

  load_devices
  landed="$(switch_to "$target" "$step")"
  render on "$landed"
  release_lock
}

step_device() {
  local step="$1" serial base index count target

  acquire_lock

  # Stamp the suppression deadline before anything can switch a device: the
  # switch fires a volume_change ~0.5s later, and volume.sh must already know not
  # to reveal the slider under the popup. Collapse it now so the bar geometry
  # settles in one step rather than shifting while the menu is up.
  suppress_slider "$HIDE_AFTER"
  collapse_slider_now

  # Walk on from where the last uncommitted press left off, or from the device
  # actually in use when starting a fresh walk. Mid-walk presses reuse the cached
  # device list so they cost no CoreAudio round trip at all.
  if [ -r "$PENDING_FILE" ]; then
    serial="$(sed -n 1p "$PENDING_FILE")"
    base="$(sed -n 3p "$PENDING_FILE")"
  fi

  if [ -n "${base:-}" ]; then
    load_devices reuse
  else
    load_devices
  fi

  count=${#DEVICE_NAMES[@]}
  if [ "$count" -le 1 ]; then
    render on "$(current_output_name)"
    release_lock
    auto_hide_devices
    return 0
  fi

  [ -n "${serial:-}" ] || serial=0
  [ -n "${base:-}" ] || base="$(current_output_name)"

  index="$(device_index "$base")" || index=0
  target="${DEVICE_NAMES[$(((index + step + count) % count))]}"

  serial=$((serial + 1))
  printf '%s\n%s\n%s\n' "$serial" "$step" "$target" >"$PENDING_FILE"

  render on "$target"
  release_lock

  commit_pending "$serial"
  auto_hide_devices
}

case "${1:-toggle}" in
"toggle")
  acquire_lock
  load_devices
  INITIAL_DRAWING="$(sketchybar --query "$ITEM" | jq -r ".popup.drawing")"
  render toggle "$(current_output_name)"
  release_lock
  if [ "$INITIAL_DRAWING" != "on" ]; then
    auto_hide_devices
  fi
  ;;
"next")
  step_device 1
  ;;
"prev")
  step_device -1
  ;;
"select")
  acquire_lock
  rm -f "$PENDING_FILE"
  SwitchAudioSource -s "$2" >/dev/null
  load_devices
  render off "$(current_output_name)"
  release_lock
  release_slider
  ;;
esac
