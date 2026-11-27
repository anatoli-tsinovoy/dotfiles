#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
STOCK_FONT="$HOME/Library/Fonts/sketchybar-app-font.ttf"
OVERRIDES="$SCRIPT_DIR/overrides.json"
BUILDER="$SCRIPT_DIR/build-overlay.py"
INSTALLER="$SCRIPT_DIR/install-sketchybar-app-font.sh"
CONFIG_ROOT="${1:-}"
SHELL_ROOT="$CONFIG_ROOT/omniwm/shell"
FONT_DIR="$SHELL_ROOT/fonts"
LIB_DIR="$SHELL_ROOT/lib"
FONT_DEST="$FONT_DIR/sketchybar-app-font-local.ttf"
MAP_DEST="$LIB_DIR/app-font-map.luau"
MAP_STAMP="$LIB_DIR/app-font-map.sha256"

fail() {
  printf 'install-sketchybar-app-font: error: %s\n' "$*" >&2
  exit 1
}
[[ $# -eq 1 ]] || fail "usage: $0 <absolute-config-root>"
[[ "$CONFIG_ROOT" == /* ]] || fail "config root must be an absolute path: $CONFIG_ROOT"

physical_candidate() {
  local candidate="$1" tail="" parent
  while [[ ! -d "$candidate" ]]; do
    [[ "$candidate" != / ]] || break
    tail="/$(basename "$candidate")$tail"
    parent="$(dirname "$candidate")"
    [[ "$parent" != "$candidate" ]] || break
    candidate="$parent"
  done
  [[ -d "$candidate" ]] || fail "cannot resolve output directory: $1"
  printf '%s%s' "$(cd "$candidate" && pwd -P)" "$tail"
}

check_output_paths() {
  local path resolved
  for path in "$CONFIG_ROOT/omniwm" "$SHELL_ROOT" "$FONT_DIR" "$LIB_DIR" "$FONT_DEST" "$MAP_DEST" "$MAP_STAMP"; do
    if [[ -L "$path" ]]; then
      fail "$path is a symlink; the installer will not write into a Stow checkout"
    fi
    resolved="$(physical_candidate "$path")"
    case "$resolved/" in
      "$REPO_ROOT/"*)
        fail "configured OmniWM output resolves inside the dotfiles checkout: $resolved"
        ;;
    esac
  done
}
check_output_paths

[[ -f "$STOCK_FONT" ]] || fail "stock font not found at $STOCK_FONT; provide the sketchybar-app-font TTF first (this script does not install SketchyBar)"
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

if [[ -s "$FONT_DEST" && -s "$MAP_DEST" && -f "$MAP_STAMP" ]]; then
  IFS= read -r cached_fingerprint < "$MAP_STAMP" || cached_fingerprint=""
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

mkdir -p "$FONT_DIR" "$LIB_DIR"
check_output_paths
"$UV" run --quiet --python 3.13 --script "$BUILDER" \
  --stock-font "$STOCK_FONT" \
  --overrides "$OVERRIDES" \
  --svg-dir "$SCRIPT_DIR/svgs" \
  --font-output "$FONT_DEST" \
  --map-output "$MAP_DEST"

stamp_tmp="$(mktemp "$MAP_STAMP.XXXXXX")"
trap 'rm -f "$stamp_tmp"' EXIT
printf '%s\n' "$fingerprint" > "$stamp_tmp"
mv -f "$stamp_tmp" "$MAP_STAMP"
trap - EXIT
