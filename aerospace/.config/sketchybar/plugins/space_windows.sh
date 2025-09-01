#!/bin/bash

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/plugins/map_monitors.sh"

AEROSPACE_FOCUSED_MONITOR=$(aerospace list-monitors --focused | awk '{print $1}')
AEROSAPCE_WORKSPACE_FOCUSED_MONITOR=$(aerospace list-workspaces --monitor focused --empty no)
AEROSPACE_EMPTY_WORKSPACE=$(aerospace list-workspaces --monitor focused --empty)

reload_workspace_icon() {
  local -n args_=$2
  apps=$(aerospace list-windows --workspace "$@" | awk -F'|' '{gsub(/^ *| *$/, "", $2); print $2}')

  icon_strip=" "
  if [ "${apps}" != "" ]; then
    while read -r app; do
      icon_strip+=" $($CONFIG_DIR/plugins/icon_map.sh "$app")"
    done <<<"${apps}"
  else
    icon_strip=" —"
  fi

  args_+=(--animate sin 10 --set space.$@ label="$icon_strip" display=${SB_AS_MONITOR_MAP["$3"]})
}

if [ "$SENDER" = "aerospace_workspace_change" ]; then
  args=()
  for display_id in "${!SB_AS_MONITOR_MAP[@]}"; do
    if aerospace list-workspaces --monitor "${SB_AS_MONITOR_MAP[$display_id]}" | grep -Fxq -- "$AEROSPACE_PREV_WORKSPACE"; then
      AEROSPACE_PREV_MONITOR=$display_id
    fi
  done

  # The simplest solution here is just to basically rebuild the entire 'spaces' item, on each monitor, as we do in spaces.sh
  # if [ $i = "$FOCUSED_WORKSPACE" ]; then
  #   sketchybar --set space.$FOCUSED_WORKSPACE background.drawing=on
  # else
  #   sketchybar --set space.$FOCUSED_WORKSPACE background.drawing=off
  # fi
  #echo 'space_windows_change: '$AEROSPACE_FOCUSED_WORKSPACE >> ~/aaaa
  #echo space: $space >> ~/aaaa
  #space="$(echo "$INFO" | jq -r '.space')"
  #apps="$(echo "$INFO" | jq -r '.apps | keys[]')"
  # apps=$(aerospace list-windows --workspace $AEROSPACE_FOCUSED_WORKSPACE | awk -F'|' '{gsub(/^ *| *$/, "", $2); print $2}')
  #
  # icon_strip=" "
  # if [ "${apps}" != "" ]; then
  #   while read -r app
  #   do
  #     icon_strip+=" $($CONFIG_DIR/plugins/icon_map.sh "$app")"
  #   done <<< "${apps}"
  # else
  #   icon_strip=" —"
  # fi

  reload_workspace_icon "$AEROSPACE_PREV_WORKSPACE" args $AEROSPACE_PREV_MONITOR
  reload_workspace_icon "$AEROSPACE_FOCUSED_WORKSPACE" args $AEROSPACE_FOCUSED_MONITOR

  # current workspace space border color
  args+=(--set space.$AEROSPACE_FOCUSED_WORKSPACE
    icon.highlight=true
    label.highlight=true
    background.border_color=$GREEN
  )
  # prev workspace space border color
  args+=(--set space.$AEROSPACE_PREV_WORKSPACE
    icon.highlight=false
    label.highlight=false
    background.border_color=$BACKGROUND_2
  )

  for i in $AEROSPACE_EMPTY_WORKSPACE; do
    if [ "$i" -eq $AEROSPACE_FOCUSED_WORKSPACE ]; then
      continue
    fi
    args+=(--set space.$i display=0)
  done

  if [ ${#args[@]} -gt 0 ]; then
    sketchybar "${args[@]}"
  fi
fi
