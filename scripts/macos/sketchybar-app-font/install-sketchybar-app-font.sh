#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOCK_FONT="$HOME/Library/Fonts/sketchybar-app-font.ttf"
FONT_DEST="$HOME/Library/Fonts/sketchybar-app-font-local.ttf"
OVERRIDES="$SCRIPT_DIR/overrides.json"
BUILDER="$SCRIPT_DIR/build-overlay.py"
INSTALLER="$SCRIPT_DIR/install-sketchybar-app-font.sh"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar-app-font"
MAP_DEST="$CACHE_DIR/icon_map.sh"
STAMP="$CACHE_DIR/build.sha256"

fail() {
  printf 'install-sketchybar-app-font: error: %s\n' "$*" >&2
  exit 1
}

[[ -f "$STOCK_FONT" ]] || fail "stock Homebrew font not found at $STOCK_FONT; install font-sketchybar-app-font first"
[[ -f "$OVERRIDES" ]] || fail "override manifest not found at $OVERRIDES"
[[ -f "$BUILDER" ]] || fail "overlay builder not found at $BUILDER"
command -v shasum >/dev/null 2>&1 || fail "shasum is required to fingerprint the overlay inputs"

fingerprint="$(
  {
    shasum -a 256 "$STOCK_FONT" "$OVERRIDES" "$BUILDER" "$INSTALLER"
    for svg in "$SCRIPT_DIR"/svgs/*.svg; do
      [[ -f "$svg" ]] || continue
      shasum -a 256 "$svg"
    done
  } | shasum -a 256 | cut -d ' ' -f 1
)"

if [[ -s "$FONT_DEST" && -s "$MAP_DEST" && -f "$STAMP" ]]; then
  IFS= read -r cached_fingerprint < "$STAMP" || cached_fingerprint=""
  if [[ "$cached_fingerprint" == "$fingerprint" ]]; then
    exit 0
  fi
fi

UV="$(command -v uv 2>/dev/null || true)"
if [[ -z "$UV" ]]; then
  for candidate in /opt/homebrew/bin/uv /usr/local/bin/uv; do
    if [[ -x "$candidate" ]]; then
      UV="$candidate"
      break
    fi
  done
fi
[[ -n "$UV" ]] || fail "uv is required to build the isolated FontTools overlay"

mkdir -p "$(dirname "$FONT_DEST")" "$CACHE_DIR"
"$UV" run --quiet --python 3.13 --script "$BUILDER" \
  --stock-font "$STOCK_FONT" \
  --overrides "$OVERRIDES" \
  --svg-dir "$SCRIPT_DIR/svgs" \
  --font-output "$FONT_DEST" \
  --map-output "$MAP_DEST"

stamp_tmp="$(mktemp "$STAMP.XXXXXX")"
trap 'rm -f "$stamp_tmp"' EXIT
printf '%s\n' "$fingerprint" > "$stamp_tmp"
mv -f "$stamp_tmp" "$STAMP"
trap - EXIT
