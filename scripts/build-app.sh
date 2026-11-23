#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# 1. 编译 release 可执行文件
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

# 2. 组装 .app bundle
APP_DIR="$ROOT_DIR/build/Launchpad27.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN_DIR/Launchpad27" "$APP_DIR/Contents/MacOS/Launchpad27"
cp "$ROOT_DIR/Support/Info.plist" "$APP_DIR/Contents/Info.plist"

# 内置系统启动台图标（源缺失时跳过，不中断打包）
ICON_SRC="/System/Applications/Apps.app/Contents/Resources/AppIcon.icns"
if [ -f "$ICON_SRC" ]; then
	cp "$ICON_SRC" "$APP_DIR/Contents/Resources/AppIcon.icns"
else
	echo "未找到系统启动台图标，跳过内置图标：$ICON_SRC"
fi

# 3. ad-hoc 签名
codesign --force --sign - "$APP_DIR"

echo "产物路径：$APP_DIR"
