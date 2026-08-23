#!/usr/bin/env bash
set -euo pipefail

lock_file="${TMPDIR:-/tmp}/restart-sketchybar.lock"
if ! shlock -f "$lock_file" -p "$$"; then
  exit 0
fi
trap 'rm -f "$lock_file"' EXIT HUP INT TERM

brew services restart sketchybar

for ((attempt = 0; attempt < 100; attempt++)); do
  if sketchybar --query volume_source >/dev/null 2>&1; then
    exit 0
  fi
  sleep 0.1
done

echo "SketchyBar did not finish loading after restart" >&2
exit 1
