#!/usr/bin/env bash

sleep 0.05

IS_FULLSCREEN=$(aerospace list-windows --focused --format '%{window-is-fullscreen}' 2>/dev/null || true)
if [ "$IS_FULLSCREEN" != "true" ]; then
  IS_FULLSCREEN="false"
fi

STATE_DIR="${TMPDIR:-/tmp}/aerospace"
STATE_FILE="$STATE_DIR/fullscreen-borders-state"
mkdir -p "$STATE_DIR"

if [ "${1:-}" != "sync" ] && [ -r "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "$IS_FULLSCREEN" ]; then
  exit 0
fi

if [ "$IS_FULLSCREEN" = "true" ]; then
  borders ax_focus=off blacklist="" whitelist="" width=6 \
    active_color="gradient(top_left=0xffc47891,bottom_right=0xffffd44f)" \
    inactive_color="gradient(top_left=0x00FFC9D7,bottom_right=0xffF3F0DF)"
else
  borders ax_focus=off blacklist="" whitelist="" width=6 \
    active_color="gradient(top_left=0xff00C8AB,bottom_right=0xff8217FF)" \
    inactive_color="gradient(top_left=0x00FFC9D7,bottom_right=0xffF3F0DF)"
fi

printf '%s\n' "$IS_FULLSCREEN" >"$STATE_FILE"
