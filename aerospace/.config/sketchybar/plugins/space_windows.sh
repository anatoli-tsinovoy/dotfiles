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

# START_TIME=$(gdate +%s%3N)
ALL_APPS=$(aerospace list-windows --all --format '%{workspace} %{app-name}')
# this should be enough actually $(aerospace list-windows --all --format '%{workspace} %{workspace-is-focused} %{workspace-is-visible} %{monitor-id} %{app-name}')
ALL_AS_WS=$(aerospace list-workspaces --all --format '%{workspace} %{workspace-is-focused} %{workspace-is-visible} %{monitor-id}')

if [ "$SENDER" = "front_app_switched" ]; then
  while IFS=" " read -r sid is_focused is_visible as_monitor; do
    if [ "$is_focused" = "true" ]; then
      AS_FOCUSED_MONITOR=$as_monitor
      AS_FOCUSED_WS=$sid
    fi
  done <<<"${ALL_AS_WS}"
  args=()
  reload_workspace_icon "$ALL_APPS" args $AS_FOCUSED_WS $AS_FOCUSED_MONITOR 1 0

  if [ ${#args[@]} -gt 0 ]; then
    sketchybar "${args[@]}"
  fi
fi

if [ "$SENDER" = "aerospace_monitor_move" ]; then
  while IFS=" " read -r sid is_focused is_visible as_monitor; do
    if [ "$is_focused" = "true" ]; then
      AS_FOCUSED_MONITOR=$as_monitor
      AS_FOCUSED_WS=$sid
    fi
  done <<<"${ALL_AS_WS}"

  args=()
  reload_workspace_icon "$ALL_APPS" args $AS_FOCUSED_WS $AS_FOCUSED_MONITOR 1 0

  if [ ${#args[@]} -gt 0 ]; then
    sketchybar "${args[@]}"
  fi
fi

if [ "$SENDER" = "aerospace_workspace_change" ]; then
  AS_NONEMPTY_WS=""
  while read -r sid app_names; do
    AS_NONEMPTY_WS+="$sid"$'\n'
  done <<<"${ALL_APPS}"
  AS_NONEMPTY_WS=" ${AS_NONEMPTY_WS//$'\n'/ }"

  AS_EMPTY_WS=""
  while IFS=" " read -r sid is_focused is_visible as_monitor; do
    if [ "$sid" = "$AS_PREV_WS" ]; then
      AS_PREV_MONITOR=$as_monitor
    fi

    if [ "$is_focused" = "true" ]; then
      AS_FOCUSED_MONITOR=$as_monitor
    fi

    if [[ ! " $AS_NONEMPTY_WS " == *" $sid "* ]]; then
      AS_EMPTY_WS+="$sid"$'\n'
    fi
  done <<<"${ALL_AS_WS}"

  args=()
  for i in $AS_EMPTY_WS; do
    if [ "$i" -eq $AS_FOCUSED_WS ]; then
      continue
    fi
    if [ "$i" -eq $AS_PREV_WS ]; then
      AS_PREV_WS_IS_EMPTY=1
    fi
    args+=(--set space.$i display=0)
  done
  reload_workspace_icon "$ALL_APPS" args $AS_PREV_WS $AS_PREV_MONITOR 0 $AS_PREV_WS_IS_EMPTY
  reload_workspace_icon "$ALL_APPS" args $AS_FOCUSED_WS $AS_FOCUSED_MONITOR 1 0
  if [ ${#args[@]} -gt 0 ]; then
    sketchybar "${args[@]}"
  fi
  # SB_END=$(gdate +%s%3N)
  # echo "TIME: $((SB_END - START_TIME))" >>~/aaaa
fi
