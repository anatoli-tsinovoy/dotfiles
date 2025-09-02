#!/bin/bash

source "$CONFIG_DIR/colors.sh"
read -a AS_TO_SB <<<"$(sketchybar --query AS_TO_SB | jq -r '.label.value')"

reload_workspace_icon() {
  local all_apps=$1
  local outvar=$2
  local args_=()
  apps=""
  while read -r sid app_name; do
    if [ "$sid" = "$3" ]; then
      apps+="$app_name"$'\n'
    fi
  done <<<"$all_apps"
  apps=${apps%$'\n'}

  icon_strip=" "
  if [ "${apps}" != "" ]; then
    while read -r app; do
      icon_strip+=" $($CONFIG_DIR/plugins/icon_map.sh "$app")"
    done <<<"$apps"
  else
    icon_strip=" —"
  fi
  if [ "$5" = 1 ]; then
    SID_ICON_HIGHLIGHT="true"
    SID_LABEL_HIGHLIGHT="true"
    SID_BORDER_COLOR=$GREEN
    # AS_TO_SB is zero-based, but as_monitor is one-based
    SID_DISPLAY=${AS_TO_SB[(($4 - 1))]}
  else
    SID_ICON_HIGHLIGHT="false"
    SID_LABEL_HIGHLIGHT="false"
    SID_BORDER_COLOR=$BACKGROUND_1
    if [ $6 ]; then
      SID_DISPLAY=0
    else
      # AS_TO_SB is zero-based, but as_monitor is one-based
      SID_DISPLAY=${AS_TO_SB[(($4 - 1))]}
    fi
  fi
  args_+=(--animate sin "10"
    --set space.$3
    display="$SID_DISPLAY"
    label="$icon_strip"
    icon.highlight="$SID_ICON_HIGHLIGHT"
    label.highlight="$SID_LABEL_HIGHLIGHT"
    background.border_color="$SID_BORDER_COLOR"
  )

  eval "$outvar+=(\"\${args_[@]}\")"
}

if [ "$SENDER" = "aerospace_workspace_change" ]; then
  ALL_APPS=$(aerospace list-windows --all --format '%{workspace} %{app-name}')
  # TODO: This is only the empty workspaces on the newly-in-focus monitor
  AEROSPACE_EMPTY_WORKSPACE=$(aerospace list-workspaces --monitor focused --empty)
  while IFS=" " read -r sid is_focused is_visible as_monitor; do
    if [ "$sid" = "$AEROSPACE_PREV_WORKSPACE" ]; then
      AEROSPACE_PREV_MONITOR=$as_monitor
    fi

    if [ "$is_focused" = "true" ]; then
      AEROSPACE_FOCUSED_MONITOR=$as_monitor
    fi
  done < <(aerospace list-workspaces --all --format '%{workspace} %{workspace-is-focused} %{workspace-is-visible} %{monitor-id}')

  args=()
  for i in $AEROSPACE_EMPTY_WORKSPACE; do
    if [ "$i" -eq $AEROSPACE_FOCUSED_WORKSPACE ]; then
      continue
    fi
    if [ "$i" -eq $AEROSPACE_PREV_WORKSPACE ]; then
      AS_PREV_WS_IS_EMPTY=1
    fi
    args+=(--set space.$i display=0)
  done
  reload_workspace_icon "$ALL_APPS" args $AEROSPACE_PREV_WORKSPACE $AEROSPACE_PREV_MONITOR 0 $AS_PREV_WS_IS_EMPTY
  reload_workspace_icon "$ALL_APPS" args $AEROSPACE_FOCUSED_WORKSPACE $AEROSPACE_FOCUSED_MONITOR 1 0
  if [ ${#args[@]} -gt 0 ]; then
    sketchybar "${args[@]}"
  fi
fi
