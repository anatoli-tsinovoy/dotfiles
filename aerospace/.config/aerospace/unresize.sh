#!/usr/bin/env bash
if ! aerospace list-windows --workspace focused --format '%{window-id}' | ~/.config/aerospace/winbounds; then
  aerospace resize "$@"
fi
