#!/bin/bash

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/plugins/map_monitors.sh"

reload_workspace_icon() {
  local outvar=$1
  local args_=()
  apps=$(aerospace list-windows --workspace "$2" | awk -F'|' '{gsub(/^ *| *$/, "", $2); print $2}')
  icon_strip=" "
  if [ "${apps}" != "" ]; then
    while read -r app; do
      icon_strip+=" $($CONFIG_DIR/plugins/icon_map.sh "$app")"
    done <<<"${apps}"
  else
    icon_strip=" —"
  fi
  if [ "$4" = 1 ]; then
    SID_ICON_HIGHLIGHT="true"
    SID_LABEL_HIGHLIGHT="true"
    SID_BORDER_COLOR=$GREEN
    SID_DISPLAY=${AS_TO_SB["$3"]}
  else
    SID_ICON_HIGHLIGHT="false"
    SID_LABEL_HIGHLIGHT="false"
    SID_BORDER_COLOR=$BACKGROUND_1
    if [ -z "$(aerospace list-windows --workspace $2)" ]; then
      SID_DISPLAY=0
    else
      SID_DISPLAY=${AS_TO_SB["$3"]}
    fi
  fi
  args_+=(--animate sin "10"
    --set space.$2
    display="$SID_DISPLAY"
    label="$icon_strip"
    icon.highlight="$SID_ICON_HIGHLIGHT"
    label.highlight="$SID_LABEL_HIGHLIGHT"
    background.border_color="$SID_BORDER_COLOR"
  )

  eval "$outvar+=(\"\${args_[@]}\")"
}

if [ "$SENDER" = "aerospace_workspace_change" ]; then

  AEROSAPCE_WORKSPACE_FOCUSED_MONITOR=$(aerospace list-workspaces --monitor focused --empty no)
  # TODO: This is only the empty workspaces on the newly-in-focus monitor
  AEROSPACE_EMPTY_WORKSPACE=$(aerospace list-workspaces --monitor focused --empty)

  args=()
  for as_monitor in "${!AS_TO_SB[@]}"; do
    if aerospace list-workspaces --monitor $as_monitor | grep -Fxq -- "$AEROSPACE_PREV_WORKSPACE"; then
      AEROSPACE_PREV_MONITOR=$as_monitor
    fi
  done

  for i in $AEROSPACE_EMPTY_WORKSPACE; do
    if [ "$i" -eq $AEROSPACE_FOCUSED_WORKSPACE ]; then
      continue
    fi
    args+=(--set space.$i display=0)
  done

  AEROSPACE_FOCUSED_MONITOR=$(aerospace list-monitors --focused | awk '{print $1}')
  reload_workspace_icon args $AEROSPACE_PREV_WORKSPACE $AEROSPACE_PREV_MONITOR 0
  reload_workspace_icon args $AEROSPACE_FOCUSED_WORKSPACE $AEROSPACE_FOCUSED_MONITOR 1

  if [ ${#args[@]} -gt 0 ]; then
    sketchybar "${args[@]}"
  fi
fi
