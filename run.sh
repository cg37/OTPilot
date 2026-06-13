#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="SMSCodeReader"
APP_BUNDLE="$SCRIPT_DIR/${APP_NAME}.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
BINARY_PATH="$MACOS_DIR/$APP_NAME"
DESKTOP_APP="$HOME/Desktop/${APP_NAME}.app"

echo "🔨 编译 SMSCodeReader..."
echo "========================================="
echo ""

# Create app bundle structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Compile Swift sources
swiftc -target arm64-apple-macos13 \
    -o "$BINARY_PATH" \
    "$SCRIPT_DIR/Sources/"*.swift \
    -framework AppKit \
    -framework UserNotifications \
    -lsqlite3

echo ""
echo "✅ 编译完成"

# Deploy to Desktop (overwrite if exists)
if [ -d "$DESKTOP_APP" ]; then
    rm -rf "$DESKTOP_APP"
fi
cp -R "$APP_BUNDLE" "$DESKTOP_APP"

echo ""
echo "启动 SMSCodeReader - 验证码自动读取工具"
echo "========================================="
echo ""
echo "注意: 首次运行需要授予以下权限:"
echo "1. 全磁盘访问权限 (用于读取 Messages 数据库)"
echo "2. 通知权限 (用于显示验证码通知)"
echo ""
echo "如果无法读取短信,请前往:"
echo "系统设置 > 隐私与安全性 > 全磁盘访问"
echo "然后添加 SMSCodeReader 到允许列表"
echo "  路径: $DESKTOP_APP"
echo ""
echo "开始运行..."
echo ""

# Launch the app bundle
open "$DESKTOP_APP"
