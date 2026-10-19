#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-release}"
APP_NAME="Wizclip"
BUNDLE_ID="com.wiz.wizclip"
BUILD_BIN="$ROOT/.build/$CONFIG/Wizclip"
APP_DIR="$ROOT/dist/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

swift build -c "$CONFIG" --product Wizclip >&2

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"
cp "$BUILD_BIN" "$MACOS_DIR/$APP_NAME"
printf 'APPLWZCL' > "$APP_DIR/Contents/PkgInfo"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDisplayName</key>
	<string>Wizclip</string>
	<key>CFBundleExecutable</key>
	<string>Wizclip</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Wizclip</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.utilities</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
PLIST

if [[ ! -f "$ROOT/Wizclip/Resources/AppIcon.icns" ]]; then
  "$ROOT/scripts/make-icon.sh" >&2
fi
cp "$ROOT/Wizclip/Resources/AppIcon.icns" "$RES_DIR/AppIcon.icns"

chmod +x "$MACOS_DIR/$APP_NAME"
codesign --force --deep --sign - "$APP_DIR" >&2
echo "$APP_DIR"
