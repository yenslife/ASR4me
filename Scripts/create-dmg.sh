#!/bin/bash
set -e

APP_NAME="ASR4me"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
DMG_CONTENT_DIR="$BUILD_DIR/dmg_content"
EXPORT_DIR="$BUILD_DIR/export"
BACKGROUND_DIR="$PROJECT_DIR/Resources"
BACKGROUND_IMAGE="$BACKGROUND_DIR/dmg-background.png"
FINAL_DMG="$BUILD_DIR/$APP_NAME.dmg"

echo "===== 1/6 編譯並封存 ====="
xcodebuild -project "$PROJECT_DIR/ASR4me/ASR4me.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
  archive

echo ""
echo "===== 2/6 匯出 .app ====="
xcodebuild -exportArchive \
  -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$SCRIPT_DIR/exportOptions.plist"

echo ""
echo "===== 3/6 準備 DMG 內容 ====="
rm -rf "$DMG_CONTENT_DIR"
mkdir -p "$DMG_CONTENT_DIR"
cp -R "$EXPORT_DIR/$APP_NAME.app" "$DMG_CONTENT_DIR/"

# 建立 /Applications 的替身
ln -s /Applications "$DMG_CONTENT_DIR/Applications"

echo ""
echo "===== 4/6 建立暫存 DMG 並掛載 ====="

# 卸載任何殘留的 ASR4me 掛載（避免前次失敗遺留的 read-only 掛載）
if [ -d "/Volumes/$APP_NAME" ]; then
  echo "  卸載殘留的 /Volumes/$APP_NAME ..."
  hdiutil detach "/Volumes/$APP_NAME" -force 2>/dev/null || true
fi

TEMP_DMG="$BUILD_DIR/temp_rw.dmg"
rm -f "$TEMP_DMG"

# 計算所需大小（app 大小 + 緩衝）
APP_SIZE_KB=$(du -sk "$DMG_CONTENT_DIR" | cut -f1)
DMG_SIZE_MB=$(( (APP_SIZE_KB / 1024) + 20 ))
echo "  DMG 大小: ${DMG_SIZE_MB}MB"

hdiutil create -srcfolder "$DMG_CONTENT_DIR" \
  -volname "$APP_NAME" \
  -fs HFS+ \
  -fsargs "-c c=64,a=16,e=16" \
  -format UDRW \
  -size "${DMG_SIZE_MB}m" \
  "$TEMP_DMG"

DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" | \
         egrep '^/dev/' | sed 1q | awk '{print $1}')

if [ -z "$DEVICE" ]; then
  echo "❌ 無法掛載 DMG"
  exit 1
fi

MOUNT_POINT="/Volumes/$APP_NAME"
echo "  已掛載於: $MOUNT_POINT"

echo ""
echo "===== 5/6 設定 DMG 佈局 ====="

# 複製背景圖
mkdir -p "$MOUNT_POINT/.background"
if [ -f "$BACKGROUND_IMAGE" ]; then
  cp "$BACKGROUND_IMAGE" "$MOUNT_POINT/.background/background.png"
  echo "  已複製背景圖"
else
  echo "  ⚠️  找不到 $BACKGROUND_IMAGE，使用預設白色背景"
  echo "  提示：將背景圖放在 Resources/dmg-background.png（建議 660x400）"
fi

# 使用 AppleScript 設定 Finder 視窗外觀與圖示位置
osascript <<EOF
tell application "Finder"
  tell disk "$APP_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {400, 200, 1060, 600}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 96
    set text size of theViewOptions to 13
    if exists file ".background:background.png" then
      set background picture of theViewOptions to file ".background:background.png"
    end if
    set position of item "$APP_NAME.app" of container window to {180, 180}
    set position of item "Applications" of container window to {480, 180}
    update without registering applications
    close
    open
    delay 1
    update without registering applications
    delay 1
  end tell
end tell
EOF

echo "  佈局設定完成"

echo ""
echo "===== 6/6 卸載並產生最終 DMG ====="
hdiutil detach "$DEVICE" -force
hdiutil convert "$TEMP_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$FINAL_DMG"

rm -f "$TEMP_DMG"

echo ""
echo "✅ 完成: $FINAL_DMG"
echo "   大小: $(du -sh "$FINAL_DMG" | cut -f1)"
