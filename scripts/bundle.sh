#!/usr/bin/env bash
#
# 把 Sitizen 打包成可双击运行的 .app（以及可选的 .dmg）。
#
#   ./scripts/bundle.sh              # 通用二进制（arm64 + x86_64），ad-hoc 签名
#   SITIZEN_ARCHS=arm64 ./scripts/bundle.sh
#   SITIZEN_SIGN_IDENTITY="Developer ID Application: XXX (TEAMID)" ./scripts/bundle.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="Sitizen"
PLIST="Resources/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
IDENTITY="${SITIZEN_SIGN_IDENTITY:--}"
ARCHS="${SITIZEN_ARCHS:-arm64 x86_64}"

echo "==> [1/5] 编译 Release（${ARCHS}）"
ARCH_FLAGS=()
for arch in $ARCHS; do
  ARCH_FLAGS+=(--arch "$arch")
done
swift build -c release "${ARCH_FLAGS[@]}"
BIN_DIR="$(swift build -c release "${ARCH_FLAGS[@]}" --show-bin-path)"
BIN="${BIN_DIR}/${APP_NAME}"

# 图标由 App 自己渲染：设置页里那只吉祥物就是唯一的图源，不做第二份拷贝。
echo "==> [2/5] 生成图标"
"${BIN}" --render-appicon Resources/icon.iconset > /dev/null
iconutil -c icns Resources/icon.iconset -o Resources/AppIcon.icns

echo "==> [3/5] 组装 ${APP_NAME}.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "${APP}/Contents/MacOS/${APP_NAME}"
cp "$PLIST" "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> [4/5] 签名（identity: ${IDENTITY}）"
if [ "$IDENTITY" = "-" ]; then
  codesign --force --deep --sign - "$APP"
else
  codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$APP"
fi
codesign --verify --verbose=2 "$APP"

echo "==> [5/5] 完成"
echo "    产物：${APP}"
echo "    版本：${VERSION} (${BUILD})"
echo "    架构：$(lipo -archs "${APP}/Contents/MacOS/${APP_NAME}")"
echo
echo "    运行：open \"${APP}\""
