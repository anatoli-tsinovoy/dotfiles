#!/bin/bash

#SPACE_ICONS=("1 IC1 IC2" "2 IC3 IC4" "3 IC5" "4 IC6")
# aerospace setting

declare -A SB_AS_MONITOR_MAP
while IFS=" " read -r monitor_id display_id; do
  SB_AS_MONITOR_MAP["$monitor_id"]="$display_id"
done < <(aerospace list-monitors --format '%{monitor-id} %{monitor-appkit-nsscreen-screens-id}')

AEROSPACE_FOCUSED_WS=$(aerospace list-workspaces --focused)

args=()
args+=(--add event aerospace_workspace_change)
args+=(--add event aerospace_focus_change)
for m in "${SB_AS_MONITOR_MAP[@]}"; do
  for i in $(aerospace list-workspaces --monitor $m); do
    sid=$i
    if [ $sid = $AEROSPACE_FOCUSED_WS ]; then
      SID_BORDER_COLOR=$GREEN
      SID_ICON_HIGHLIGHT="true"
      SID_LABEL_HIGHLIGHT="true"
    else
      SID_BORDER_COLOR=$BACKGROUND_1
      SID_ICON_HIGHLIGHT="false"
      SID_LABEL_HIGHLIGHT="false"
    fi
    space=(
      space="$sid"
      icon="$sid"
      icon.highlight_color=$GREEN
      icon.padding_left=10
      icon.padding_right=10
      display="${SB_AS_MONITOR_MAP["$m"]}"
      padding_left=2
      padding_right=2
      label.padding_right=20
      icon.color=$MAGENTA
      icon.highlight=$SID_ICON_HIGHLIGHT
      label.color=$BLUE
      label.highlight_color=$GREEN
      label.highlight=$SID_LABEL_HIGHLIGHT
      label.font="sketchybar-app-font:Regular:16.0"
      label.y_offset=-1
      background.color=$BG0
      background.border_color=$SID_BORDER_COLOR
      script="$PLUGIN_DIR/space.sh"
    )
    args+=(--add space space.$sid left)
    args+=(--set space.$sid "${space[@]}")
    args+=(--subscribe space.$sid mouse.clicked)
    args+=(--subscribe space.$sid aerospace_workspace_change)
    # args+=(--subscribe space.$sid aerospace_focus_change)

    apps=$(aerospace list-windows --workspace $sid | awk -F'|' '{gsub(/^ *| *$/, "", $2); print $2}')

    icon_strip=" "
    if [ "${apps}" != "" ]; then
      while read -r app; do
        icon_strip+=" $($CONFIG_DIR/plugins/icon_map.sh "$app")"
      done <<<"${apps}"
    else
      icon_strip=" —"
    fi

    args+=(--set space.$sid label="$icon_strip")
  done

  for i in $(aerospace list-workspaces --monitor "$m" --empty); do
    args+=(--set space.$i display=0)
  done

done

space_creator=(
  icon="􀆊"
  icon.font="$FONT:Heavy:16.0"
  padding_left=10
  padding_right=8
  label.drawing=off
  display=active
  icon.color=$GREEN
)
args+=(--add item space_creator left)
args+=(--set space_creator "${space_creator[@]}")

args+=(--add item as_ws_changer left)
args+=(--set as_ws_changer drawing=off updates=on script="$PLUGIN_DIR/space_windows.sh")
args+=(--subscribe as_ws_changer aerospace_workspace_change)

if [ ${#args[@]} -gt 0 ]; then
  sketchybar "${args[@]}"
fi
