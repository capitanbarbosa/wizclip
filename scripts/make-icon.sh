#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Wizclip/Resources/AppIcon.png"
ICONSET="$ROOT/Wizclip/Resources/AppIcon.iconset"
ICNS="$ROOT/Wizclip/Resources/AppIcon.icns"

if [[ ! -f "$SRC" ]]; then
  echo "Missing $SRC" >&2
  exit 1
fi

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

sizes=(16 32 64 128 256 512 1024)
for size in "${sizes[@]}"; do
  sips -z "$size" "$size" "$SRC" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
done

mv "$ICONSET/icon_32x32.png" "$ICONSET/icon_16x16@2x.png"
mv "$ICONSET/icon_64x64.png" "$ICONSET/icon_32x32@2x.png"
mv "$ICONSET/icon_256x256.png" "$ICONSET/icon_128x128@2x.png"
mv "$ICONSET/icon_512x512.png" "$ICONSET/icon_256x256@2x.png"
mv "$ICONSET/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png"

sips -z 16 16 "$SRC" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$SRC" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 128 128 "$SRC" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$SRC" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$SRC" --out "$ICONSET/icon_512x512.png" >/dev/null

iconutil -c icns "$ICONSET" -o "$ICNS"
rm -rf "$ICONSET"
echo "$ICNS"
