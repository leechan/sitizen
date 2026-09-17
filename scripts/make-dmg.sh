#!/usr/bin/env bash
#
# 把 dist/Sitizen.app 打成带「拖进 Applications」安装界面的 DMG。
#
#   ./scripts/make-dmg.sh
#
# 需要先跑过 ./scripts/bundle.sh（或直接 make dmg，它依赖 bundle）。
#
# 关于布局的几个硬约束（踩过的坑）：
#   * Finder 把背景图按 1:1 像素铺在窗口内容区，**从不缩放**。
#     所以背景必须按 1x 输出，尺寸 = 窗口内容区尺寸，否则图标和箭头对不上。
#   * 图标坐标 (Iloc) 是**图标中心**，不含下方文字，单位是 1x 像素，原点在内容区左上角。
#   * 视网膜清晰度靠 1x + 2x 两份合并成多分辨率 TIFF，不是靠放大 1x。
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="Sitizen"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
APP="dist/${APP_NAME}.app"
DMG="dist/${APP_NAME}-${VERSION}.dmg"
STAGE="dist/dmg-stage"
TMP_DMG="dist/${APP_NAME}-tmp.dmg"
# 挂载点由 hdiutil 决定（同名的残留卷会让它变成 "Sitizen 1"），后面动态取
BG_BASE="dist/dmg-background"
BG_TIFF="${BG_BASE}.tiff"

# 窗口内容区尺寸，必须和 DMGBackground 的逻辑尺寸一致
WIN_W=640
WIN_H=400
WIN_LEFT=260
WIN_TOP=160
ICON_Y=185
APP_X=160
DROP_X=480

[ -d "$APP" ] || { echo "找不到 $APP，请先运行 ./scripts/bundle.sh"; exit 1; }

BIN_DIR="$(swift build -c release --show-bin-path 2>/dev/null || echo .build/debug)"
BIN="${BIN_DIR}/${APP_NAME}"
[ -x "$BIN" ] || BIN=".build/debug/${APP_NAME}"

cleanup() {
  for v in /Volumes/${APP_NAME}*; do
    [ -d "$v" ] && hdiutil detach "$v" -force > /dev/null 2>&1 || true
  done
  rm -f "$TMP_DMG"
}
trap cleanup EXIT

# 残留的旧卷会让新卷变成 "Sitizen 1"，Finder 脚本就会操作错对象
cleanup

echo "==> [1/5] 生成安装界面背景（1x + 2x → TIFF）"
rm -f "${BG_BASE}.png" "${BG_BASE}@2x.png" "$BG_TIFF"
"$BIN" --render-dmg-background "${BG_BASE}.png" 1 > /dev/null
"$BIN" --render-dmg-background "${BG_BASE}@2x.png" 2 > /dev/null
tiffutil -cathidpicheck "${BG_BASE}.png" "${BG_BASE}@2x.png" -out "$BG_TIFF" > /dev/null

echo "==> [2/5] 准备内容"
rm -rf "$STAGE"
mkdir -p "$STAGE/.background"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "$BG_TIFF" "$STAGE/.background/"

echo "==> [3/5] 创建可写 DMG"
rm -f "$DMG" "$TMP_DMG"
hdiutil create -srcfolder "$STAGE" -volname "$APP_NAME" -fs HFS+ \
  -format UDRW -ov "$TMP_DMG" > /dev/null
MOUNT_POINT="$(hdiutil attach "$TMP_DMG" -readwrite -noverify -noautoopen | grep -o '/Volumes/.*' | head -1)"
[ -n "$MOUNT_POINT" ] || { echo "挂载失败"; exit 1; }
VOLUME_NAME="$(basename "$MOUNT_POINT")"
echo "    已挂载：$MOUNT_POINT"
sleep 2

echo "==> [4/5] 排版安装界面"
if osascript <<APPLESCRIPT > /dev/null 2>&1
tell application "Finder"
  tell disk "$VOLUME_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {$WIN_LEFT, $WIN_TOP, $((WIN_LEFT + WIN_W)), $((WIN_TOP + WIN_H))}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 128
    set text size of opts to 13
    set label position of opts to bottom
    try
      set background picture of opts to file ".background:dmg-background.tiff"
    end try
    set position of item "${APP_NAME}.app" of container window to {$APP_X, $ICON_Y}
    set position of item "Applications" of container window to {$DROP_X, $ICON_Y}
    close
    open
    update without registering applications
    delay 2
    close
  end tell
end tell
APPLESCRIPT
then
  echo "    排版完成（窗口 ${WIN_W}×${WIN_H}，图标 ${APP_X}/${DROP_X} @ y=${ICON_Y}）"
else
  echo "    (跳过自定义排版：Finder 自动化不可用，DMG 仍可直接拖拽安装)"
fi

sync
sleep 1
for _ in 1 2 3 4 5; do
  hdiutil detach "$MOUNT_POINT" > /dev/null 2>&1 && break
  sleep 1
  hdiutil detach "$MOUNT_POINT" -force > /dev/null 2>&1 && break
  sleep 1
done
[ -d "$MOUNT_POINT" ] && { echo "    无法卸载 $MOUNT_POINT"; exit 1; }

echo "==> [5/5] 压缩成只读 DMG"
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" > /dev/null
rm -f "$TMP_DMG"
rm -rf "$STAGE" "${BG_BASE}.png" "${BG_BASE}@2x.png"

echo
echo "完成：$DMG"
echo "大小：$(du -h "$DMG" | cut -f1)"
echo
echo "分享给他人后，对方双击打开、把 Sitizen 拖进 Applications 即可。"
echo "首次打开若被 Gatekeeper 拦下：右键 → 打开，或执行"
echo "  xattr -dr com.apple.quarantine /Applications/Sitizen.app"
