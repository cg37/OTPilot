#!/bin/bash
set -e

# 配置
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="OTPilot"
APP_VERSION="${1:-1.0.0}"
BUILD_MODE="${2:-release}"  # release 或 debug

APP_BUNDLE="$SCRIPT_DIR/${APP_NAME}.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
BINARY_PATH="$MACOS_DIR/$APP_NAME"
INSTALL_APP="/Applications/${APP_NAME}.app"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔨 编译 ${APP_NAME} v${APP_VERSION} (${BUILD_MODE} 模式)${NC}"
echo "========================================="

# 创建 app bundle 结构
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 生成 Info.plist
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.otpilot.app</string>
    <key>CFBundleVersion</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>MIT License</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>OTPilot 需要读取短信数据库以自动提取验证码。</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <false/>
</dict>
</plist>
EOF

echo -e "${GREEN}✅ Info.plist 已生成${NC}"

# 检查是否需要重新编译（增量编译检测）
NEED_COMPILE=true
if [ -f "$BINARY_PATH" ]; then
    BINARY_MTIME=$(stat -f %m "$BINARY_PATH" 2>/dev/null || echo 0)
    SOURCE_MTIME=0
    for src in "$SCRIPT_DIR/Sources/"*.swift; do
        SRC_MTIME=$(stat -f %m "$src" 2>/dev/null || echo 0)
        if [ "$SRC_MTIME" -gt "$SOURCE_MTIME" ]; then
            SOURCE_MTIME=$SRC_MTIME
        fi
    done
    
    if [ "$BINARY_MTIME" -ge "$SOURCE_MTIME" ]; then
        echo -e "${YELLOW}⏭️  源代码未变更，跳过编译${NC}"
        NEED_COMPILE=false
    fi
fi

if [ "$NEED_COMPILE" = true ]; then
    echo ""
    echo "📝 编译 Swift 源代码..."
    
    # 编译参数
    SWIFT_FLAGS="-target arm64-apple-macos13"
    
    if [ "$BUILD_MODE" = "release" ]; then
        SWIFT_FLAGS="$SWIFT_FLAGS -O -whole-module-optimization"
    else
        SWIFT_FLAGS="$SWIFT_FLAGS -Onone -g"
    fi
    
    swiftc $SWIFT_FLAGS \
        -o "$BINARY_PATH" \
        "$SCRIPT_DIR/Sources/"*.swift \
        -framework AppKit \
        -framework UserNotifications \
        -lsqlite3
    
    echo -e "${GREEN}✅ 编译完成${NC}"
fi

# Ad-hoc 代码签名（通知功能必需）
echo ""
echo "🔐 签名应用..."
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null
echo -e "${GREEN}✅ 签名完成${NC}"

# 部署到 /Applications
echo ""
echo "📦 部署到 /Applications..."
if [ -d "$INSTALL_APP" ]; then
    rm -rf "$INSTALL_APP"
fi
cp -R "$APP_BUNDLE" "$INSTALL_APP"
echo -e "${GREEN}✅ 部署完成${NC}"

# 停止旧进程
echo ""
echo "🔄 停止旧进程..."
killall "$APP_NAME" 2>/dev/null || true
sleep 1

if pgrep -f "$APP_NAME" > /dev/null; then
    echo -e "${YELLOW}⚠️  旧进程仍在运行，强制终止...${NC}"
    killall -9 "$APP_NAME" 2>/dev/null || true
    sleep 1
fi

# 启动应用
echo ""
echo -e "${GREEN}🚀 启动 ${APP_NAME} v${APP_VERSION}${NC}"
echo "========================================="
echo ""
echo "提示: 首次运行需要授予以下权限:"
echo "  1. 全磁盘访问权限 (读取 Messages 数据库)"
echo "  2. 通知权限 (显示验证码通知)"
echo ""
echo "如无法读取短信，请前往:"
echo "  系统设置 > 隐私与安全性 > 全磁盘访问"
echo "  添加: $INSTALL_APP"
echo ""

open "$INSTALL_APP"
