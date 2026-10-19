#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Wizclip"
DEST="/Applications/$APP_NAME.app"

APP_DIR="$("$ROOT/scripts/package-app.sh" release)"

pkill -f "Wizclip.app/Contents/MacOS/Wizclip" 2>/dev/null || true
pkill -f "Wiz Clipboard.app/Contents/MacOS/Wiz Clipboard" 2>/dev/null || true
sleep 0.3

rm -rf "$DEST"
rm -rf "/Applications/Wiz Clipboard.app"
cp -R "$APP_DIR" "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST" >/dev/null
open "$DEST"

echo "Installed to $DEST"
