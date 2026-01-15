#!/usr/bin/env bash
read -a AS_TO_SB <<<"$(sketchybar --query DISPLAY_CHANGE | jq -r '.label.value')"
AEROSPACE_FOCUSED_WS=$(aerospace list-workspaces --focused)

args=()
args+=(--add event aerospace_workspace_change)
args+=(--add event aerospace_focus_change)
args+=(--add event aerospace_monitor_move)
ALL_AS_WS_AS_MON=$(aerospace list-workspaces --all --format '%{workspace} %{monitor-id}')
while read -r i as_monitor; do
  sb_monitor=${AS_TO_SB[(($as_monitor - 1))]}
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
    icon="$sid"
    icon.highlight_color=$GREEN
    icon.padding_left=10
    icon.padding_right=10
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
  args+=(--subscribe space.$sid mouse.clicked)

  mapfile -t apps <<<$(aerospace list-windows --workspace "$sid" </dev/null | awk -F'|' '{gsub(/^ *| *$/, "", $2); print $2}')
  if [[ ${#apps} -gt 0 ]]; then
    icon_strip="$($CONFIG_DIR/plugins/icon_map.sh "${apps[@]}")"
  else
    icon_strip=" —"
  fi

  args+=(
    --set space.$sid "${space[@]}"
    label="$icon_strip"
    display="$sb_monitor"
  )

  for i in $(aerospace list-workspaces --monitor "$as_monitor" --empty </dev/null); do
    args+=(--set space.$i display=0)
  done

done <<<"${ALL_AS_WS_AS_MON}"
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
args+=(--subscribe as_ws_changer aerospace_focus_change)
args+=(--subscribe as_ws_changer aerospace_monitor_move)
args+=(--subscribe as_ws_changer front_app_switched)

if [ ${#args[@]} -gt 0 ]; then
  sketchybar "${args[@]}"
fi
