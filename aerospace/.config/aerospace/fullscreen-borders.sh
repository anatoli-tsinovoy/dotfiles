#!/usr/bin/env bash

sleep 0.05
IS_FULLSCREEN=$(aerospace list-windows --focused --format '%{window-is-fullscreen}' 2>/dev/null)

if [ "$IS_FULLSCREEN" = "true" ]; then
  borders active_color="gradient(top_left=0xffc47891,bottom_right=0xffffd44f," \
    inactive_color="gradient(top_left=0x00FFC9D7,bottom_right=0xffF3F0DF)"
else
  borders active_color="gradient(top_left=0xff00C8AB,bottom_right=0xff8217FF)" \
    inactive_color="gradient(top_left=0x00FFC9D7,bottom_right=0xffF3F0DF)"
fi
# This looks weird, but it's because the color change doesn't always 'take'
borders width=6
