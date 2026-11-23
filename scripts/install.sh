#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="Launchpad27.app"
TARGET_APP="/Applications/$APP_NAME"
SOURCE_APP="$ROOT_DIR/build/$APP_NAME"

# 1. 构建（失败即退出，绝不触碰 /Applications）
echo "==> 构建 $APP_NAME"
if ! bash "$ROOT_DIR/scripts/build-app.sh"; then
	echo "构建失败，已中止安装（/Applications 未被修改）" >&2
	exit 1
fi
if [ ! -d "$SOURCE_APP" ]; then
	echo "构建产物不存在：$SOURCE_APP" >&2
	exit 1
fi

# 2. 覆盖安装：精确路径校验后删除旧版本，不做备份
if [ "$TARGET_APP" != "/Applications/Launchpad27.app" ]; then
	echo "目标路径异常，拒绝删除：$TARGET_APP" >&2
	exit 1
fi
if [ -e "$TARGET_APP" ]; then
	echo "==> 删除旧版本 $TARGET_APP"
	rm -rf "$TARGET_APP"
fi
echo "==> 拷贝到 $TARGET_APP"
ditto "$SOURCE_APP" "$TARGET_APP"

# 3. 重新 ad-hoc 签名并验证
echo "==> 签名 $TARGET_APP"
codesign --force --deep --sign - "$TARGET_APP"

SIGN_STATUS="无效"
if codesign --verify --deep --strict "$TARGET_APP" >/dev/null 2>&1; then
	SIGN_STATUS="有效（ad-hoc）"
fi
echo "==> 签名信息"
codesign -dv "$TARGET_APP" 2>&1 | grep -E "^(Identifier|Format|Signature|TeamIdentifier)" || true

# 4. 注册到 LaunchServices（路径存在才调用，缺失时降级提示）
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "$LSREGISTER" ]; then
	"$LSREGISTER" -f "$TARGET_APP"
	echo "已注册到 LaunchServices"
else
	echo "未找到 lsregister，跳过 LaunchServices 注册（可用桌面双击手动刷新图标）"
fi

# 5. Dock 集成：无该条目则插入 persistent-apps 首位，仅变更时重启 Dock
DOCK_STATUS="未变更"
if ! command -v python3 >/dev/null 2>&1; then
	echo "未找到 python3，跳过 Dock 集成"
	DOCK_STATUS="跳过（无 python3）"
else
	if ! DOCK_RESULT="$(TARGET_APP="$TARGET_APP" python3 <<'PY'
import os
import plistlib
import sys
from pathlib import Path

target = os.environ["TARGET_APP"]
plist_path = Path.home() / "Library/Preferences/com.apple.dock.plist"

with plist_path.open("rb") as f:
    data = plistlib.load(f)

apps = data.get("persistent-apps", [])


def is_target(tile):
    """扫描条目 URL，指向 Launchpad27.app 即视为已存在"""
    try:
        return "Launchpad27.app" in tile["tile-data"]["file-data"]["_CFURLString"]
    except (KeyError, TypeError):
        return False


if any(is_target(tile) for tile in apps):
    print("exists")
    sys.exit(0)

entry = {
    "tile-type": "file",
    "tile-data": {
        "file-label": "Launchpad27",
        "file-data": {
            "_CFURLString": target,
            "_CFURLStringType": 0,
        },
    },
}
apps.insert(0, entry)
data["persistent-apps"] = apps

with plist_path.open("wb") as f:
    plistlib.dump(data, f)

print("added")
PY
)"; then
		echo "Dock 集成失败，跳过（不影响安装）" >&2
		DOCK_STATUS="失败（已跳过）"
	elif [ "$DOCK_RESULT" = "added" ]; then
		echo "==> 已添加到 Dock 首位，重启 Dock"
		killall Dock || true
		DOCK_STATUS="已添加到首位"
	elif [ "$DOCK_RESULT" = "exists" ]; then
		echo "Dock 已存在，跳过"
		DOCK_STATUS="已存在，跳过"
	fi
fi

# 6. 安装摘要
echo
echo "===== 安装完成 ====="
echo "安装路径：$TARGET_APP"
echo "签名状态：$SIGN_STATUS"
echo "Dock 状态：$DOCK_STATUS"
