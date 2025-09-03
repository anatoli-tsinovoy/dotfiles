#!/bin/bash

### Sonokai
# export BLACK=0xff181819
# export WHITE=0xffe2e2e3
# export RED=0xfffc5d7c
# export GREEN=0xff9ed072
# export BLUE=0xff76cce0
# export YELLOW=0xffe7c664
# export ORANGE=0xfff39660
# export MAGENTA=0xffb39df3
# export GREY=0xff7f8490
# export TRANSPARENT=0x00000000
# export BG0=0xff2c2e34
# export BG1=0xff363944
# export BG2=0xff414550
# export THEME="DARK"

if defaults read -g AppleInterfaceStyle &>/dev/null; then
  # command succeeds and prints Dark
  export THEME="DARK"
else
  # for light mode command fails and prints some odd error
  export THEME="LIGHT"
fi
if [ $THEME = "DARK" ]; then
  # Simply Dark
  export BLACK=0xff110034
  export WHITE=0xfff3f0df
  export RED=0xffff4f44
  export GREEN=0xff00c8ab
  export BLUE=0xff8217ff
  export YELLOW=0xffffd44f
  export ORANGE=0xffffe680
  export MAGENTA=0xffffc9d7
  export GREY=0xff330d81
  export TRANSPARENT=0x00000000
  export BG0=0xff110034
  export BG1=0x60330d81
  export BG2=0x60ff67ff
  export BATTERY_1=0xff00c8ab
  export BATTERY_2=0xffffd44f
  export BATTERY_3=0xffffe680
  export BATTERY_4=0xffff6767
  export BATTERY_5=0xffff4f44
else
  ## Simply Light
  export BLACK=0xff110034
  export WHITE=0xfff3f0df
  export RED=0xffcc3e34
  export GREEN=0xff009a81
  export BLUE=0xff330d81
  export YELLOW=0xffcd9a1b
  export ORANGE=0xffcdac4c
  export MAGENTA=0xffc47891
  export GREY=0xff330d81
  export TRANSPARENT=0x00000000
  export BG0=0xfff3f0df
  export BG1=0x60a289ee
  export BG2=0x60f1aaaa
  export BATTERY_1=0xff009a81
  export BATTERY_2=0xffcd9a1b
  export BATTERY_3=0xffe6b334
  export BATTERY_4=0xffcc3e34
  export BATTERY_5=xffcc3e34
fi

### Catppuccin
# export BLACK=0xff181926
# export WHITE=0xffcad3f5
# export RED=0xffed8796
# export GREEN=0xffa6da95
# export BLUE=0xff8aadf4
# export YELLOW=0xffeed49f
# export ORANGE=0xfff5a97f
# export MAGENTA=0xffc6a0f6
# export GREY=0xff939ab7
# export TRANSPARENT=0x00000000
# export BG0=0xff1e1e2e
# export BG1=0x603c3e4f
# export BG2=0x60494d64
#
# export BATTERY_1=0xffa6da95
# export BATTERY_2=0xffeed49f
# export BATTERY_3=0xfff5a97f
# export BATTERY_4=0xffee99a0
# export BATTERY_5=0xffed8796
# export THEME="DARK"

# General bar colors
export BAR_COLOR=$BG0
export BAR_BORDER_COLOR=$BG1
export BACKGROUND_1=$BG1
export BACKGROUND_2=$BG2
if [ $THEME = "LIGHT" ]; then
  export ICON_COLOR=$BLACK  # Color of all icons
  export LABEL_COLOR=$BLACK # Color of all labels
  export POPUP_BORDER_COLOR=$BLACK
  export SHADOW_COLOR=$BG1
else
  export ICON_COLOR=$WHITE  # Color of all icons
  export LABEL_COLOR=$WHITE # Color of all labels
  export POPUP_BORDER_COLOR=$WHITE
  export SHADOW_COLOR=$BG1
fi
export POPUP_BACKGROUND_COLOR=$BAR_COLOR
