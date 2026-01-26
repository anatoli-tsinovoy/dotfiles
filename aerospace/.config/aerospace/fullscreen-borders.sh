#!/usr/bin/env bash

MODE="${1:-sync}"

if [ "$MODE" = "toggle" ]; then
  WAS_FULLSCREEN=$(aerospace list-windows --focused --format '%{window-is-fullscreen}' 2>/dev/null)
  aerospace fullscreen
  sleep 0.05
  if [ "$WAS_FULLSCREEN" = "true" ]; then
    MODE="leaving"
  else
    MODE="entering"
  fi
elif [ "$MODE" = "sync" ]; then
  IS_FULLSCREEN=$(aerospace list-windows --focused --format '%{window-is-fullscreen}' 2>/dev/null)
  if [ "$IS_FULLSCREEN" = "true" ]; then
    MODE="entering"
  else
    MODE="leaving"
  fi
fi

if [ "$MODE" = "entering" ]; then
  borders active_color="gradient(top_left=0xffff4f44,bottom_right=0xffffc9d7)" \
          inactive_color="gradient(top_left=0x00FFC9D7,bottom_right=0xffF3F0DF)" \
          width=6
else
  borders active_color="gradient(top_left=0xff00C8AB,bottom_right=0xff8217FF)" \
          inactive_color="gradient(top_left=0x00FFC9D7,bottom_right=0xffF3F0DF)" \
          width=6
fi
