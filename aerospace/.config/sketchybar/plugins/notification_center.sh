#!/usr/bin/env bash
set -euo pipefail

osascript <<'APPLESCRIPT'
tell application "System Events"
  set notificationCenterOpened to false

  try
    tell application process "SystemUIServer"
      click menu bar item "Notification Center" of menu bar 1
    end tell
    set notificationCenterOpened to true
  on error
    set notificationCenterOpened to false
  end try

  if notificationCenterOpened is false then
    try
      tell application process "ControlCenter"
        tell (first menu bar item of menu bar 1 whose description is "Clock") to click
      end tell
      set notificationCenterOpened to true
    on error
      set notificationCenterOpened to false
    end try
  end if

  if notificationCenterOpened is false then
    try
      tell application process "ControlCenter"
        tell (first menu bar item of menu bar 1 whose description is "clock") to click
      end tell
      set notificationCenterOpened to true
    on error
      set notificationCenterOpened to false
    end try
  end if

  if notificationCenterOpened is false then
    tell application process "ControlCenter"
      click menu bar item 1 of menu bar 1
    end tell
  end if
end tell
APPLESCRIPT
