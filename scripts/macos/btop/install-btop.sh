#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PATH="/Applications/btop.app"
GHOSTTY_APP="/Applications/Ghostty.app"
BTOP_BIN="/opt/homebrew/bin/btop"
BUNDLE_ID="com.local.btop"

if [[ ! -d "$GHOSTTY_APP" ]]; then
    echo "❌ Ghostty.app not found at $GHOSTTY_APP"
    exit 1
fi

if [[ ! -x "$BTOP_BIN" ]]; then
    echo "❌ btop is not executable at $BTOP_BIN"
    exit 1
fi

echo "ℹ️  Building $APP_PATH..."
rm -rf "$APP_PATH"
osacompile -o "$APP_PATH" "$SCRIPT_DIR/btop.applescript"
plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$APP_PATH/Contents/Info.plist"

if xattr -p com.apple.quarantine "$APP_PATH" >/dev/null 2>&1; then
    echo "ℹ️  Removing quarantine..."
    xattr -dr com.apple.quarantine "$APP_PATH"
fi

codesign --force --sign - "$APP_PATH"
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$APP_PATH"
mdimport "$APP_PATH"
echo "✅ Installed $APP_PATH"
