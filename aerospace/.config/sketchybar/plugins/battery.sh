#!/usr/bin/env bash

source "$CONFIG_DIR/colors.sh"

PERCENTAGE="$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)"
CHARGING="$(pmset -g batt | grep 'AC Power')"

if [ "$PERCENTAGE" = "" ]; then
  exit 0
fi

case ${PERCENTAGE} in
[8-9][0-9] | 100)
  ICON="􀛨"
  ICON_COLOR=$BATTERY_1
  ;;
[6-7][0-9])
  ICON="􀺸"
  ICON_COLOR=$BATTERY_2
  ;;
[3-5][0-9])
  ICON="􀺶"
  ICON_COLOR=$BATTERY_3
  ;;
[1-2][0-9])
  ICON="􀛩"
  ICON_COLOR=$BATTERY_4
  ;;
[0-9])
  ICON="􀛪"
  ICON_COLOR=$BATTERY_5
  ;;
esac

if [[ "$CHARGING" != "" ]]; then
  ICON="􀢋"
  ICON_COLOR=$YELLOW
fi

# The item invoking this script (name $NAME) will get its icon and label
# updated with the current battery status
sketchybar --set "$NAME" icon="$ICON" label="${PERCENTAGE}%" icon.color=${ICON_COLOR}
if [[ $SENDER == "mouse.clicked" ]]; then
  # TODO: We need to somehow allow a second click to cancel the whole thing
  LOCKDIR="/tmp/$(basename "$0").lockdir"

  if ! mkdir "$LOCKDIR" 2>/dev/null; then
    # Another instance is running (still in its sleep 5)
    exit 0
  fi

  # Ensure lock is released on exit
  trap 'rmdir "$LOCKDIR"' EXIT

  for i in 0 1; do
    LABEL_VISIBLE=$(sketchybar --query battery | jq -r ".label.drawing")
    if [[ "$LABEL_VISIBLE" == "off" ]]; then
      sketchybar --set battery label.drawing="on"
    elif [[ "$LABEL_VISIBLE" == "on" ]]; then
      sketchybar --set battery label.drawing="off"
    fi
    ((i == 0)) && sleep 5
  done
fi
