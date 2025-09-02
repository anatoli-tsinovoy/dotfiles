#!/bin/bash

declare -A NSSCREEN_TO_DIRECT
while IFS=" " read -r nsscreen_id direct_id; do
  NSSCREEN_TO_DIRECT[$nsscreen_id]="$direct_id"
done < <(swift -e 'import AppKit; import CoreGraphics; for (i, scr) in NSScreen.screens.enumerated() {
  let n = scr.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! NSNumber
  if let u = CGDisplayCreateUUIDFromDisplayID(CGDirectDisplayID(truncating: n))?.takeRetainedValue() {
    // let s = CFUUIDCreateString(nil, u) as truncating
    // print("\(i+1) \(n.intValue) \(s)")
    print("\(i+1) \(n.intValue)")
  }
}')

declare -A DIRECT_TO_SB
while IFS=" " read -r direct_id sb_monitor; do
  DIRECT_TO_SB[$direct_id]="$sb_monitor"
done < <(sketchybar --query displays | jq -r '.[] | "\(.["DirectDisplayID"]) \(.["arrangement-id"])"')

declare -A AS_TO_SB
while IFS=" " read -r as_monitor nsscreen_id; do
  AS_TO_SB[$as_monitor]=${DIRECT_TO_SB["${NSSCREEN_TO_DIRECT["$nsscreen_id"]}"]}
done < <(aerospace list-monitors --format '%{monitor-id} %{monitor-appkit-nsscreen-screens-id}')
