#!/usr/bin/env bash

source "${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar-app-font/icon_map.sh" || exit "$?"

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  for app_name in "$@"; do
    __icon_map "$app_name"
    printf '%s ' "$icon_result"
  done
  printf '\n'
fi
