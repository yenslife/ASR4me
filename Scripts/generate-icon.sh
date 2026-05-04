#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ICON_PNG="$PROJECT_DIR/icon.png"
ICONSET_DIR="$PROJECT_DIR/Resources/AppIcon.iconset"
ICNS_OUTPUT="$PROJECT_DIR/Resources/AppIcon.icns"

if [ ! -f "$ICON_PNG" ]; then
  echo "❌ 找不到 $ICON_PNG"
  exit 1
fi

echo "===== 產生 AppIcon.iconset ====="
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# 產生各尺寸圖示
sips -z 16 16     "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16.png" > /dev/null
sips -z 32 32     "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" > /dev/null
sips -z 32 32     "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32.png" > /dev/null
sips -z 64 64     "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" > /dev/null
sips -z 128 128   "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128.png" > /dev/null
sips -z 256 256   "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null
sips -z 256 256   "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256.png" > /dev/null
sips -z 512 512   "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null
sips -z 512 512   "$ICON_PNG" --out "$ICONSET_DIR/icon_512x512.png" > /dev/null
sips -z 1024 1024 "$ICON_PNG" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null

echo "===== 產生 AppIcon.icns ====="
iconutil -c icns "$ICONSET_DIR" -o "$ICNS_OUTPUT"

echo ""
echo "✅ 已產生: $ICNS_OUTPUT"
echo "   請在 Xcode 中將 Assets.xcassets 的 AppIcon 設為此 icns 檔案"
