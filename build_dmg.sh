#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="OTPilot"
APP_BUNDLE="$SCRIPT_DIR/${APP_NAME}.app"
DMG_NAME="${APP_NAME}_Installer.dmg"
DMG_PATH="$SCRIPT_DIR/$DMG_NAME"

echo "🔧 构建 DMG 安装镜像..."
echo "========================================="

# 清理旧的 DMG
rm -f "$DMG_PATH"

# 创建临时目录
TMP_DIR=$(mktemp -d)
DMG_SRC="$TMP_DIR/dmg_source"

mkdir -p "$DMG_SRC/.background"

# 复制应用到 DMG 源目录
cp -R "$APP_BUNDLE" "$DMG_SRC/${APP_NAME}.app"
codesign --force --deep --sign - "$DMG_SRC/${APP_NAME}.app"
echo "✅ 应用已签名并复制"

# 创建 Applications 符号链接
ln -s /Applications "$DMG_SRC/Applications"

# 创建临时 DMG
echo "📦 创建临时 DMG..."
hdiutil create -srcFolder "$DMG_SRC" -volname "${APP_NAME}" -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" -format UDRW -size 30m "$DMG_PATH"

# 挂载 DMG
echo "📦 配置窗口布局..."
MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_PATH" | grep -o '/Volumes/.*')

# 等待磁盘完全挂载
sleep 2

# 用 AppleScript 设置布局（如果失败不影响功能）
osascript -e "
tell application \"Finder\"
    activate
    delay 1
end tell

delay 1

tell application \"System Events\"
    tell process \"Finder\"
        set frontmost to true
    end tell
end tell

delay 1

tell application \"Finder\"
    set diskName to \"${APP_NAME}\"
    if not (exists disk diskName) then
        return
    end if
    
    set win to container window of disk diskName
    tell win
        set current view to icon view
        delay 0.5
        set toolbar visible to false
        set statusbar visible to false
        set sidebar width to 0
        set bounds to {400, 100, 1000, 500}
        delay 0.5
        tell icon view options
            set icon size to 80
            set text size to 14
            set arrangement to not arranged
        end tell
    end tell
    
    delay 0.5
    tell disk diskName
        set appItem to item \"${APP_NAME}.app\"
        set appsLink to item \"Applications\"
        set position of appItem to {450, 200}
        set position of appsLink to {150, 200}
    end tell
    
    delay 0.5
    update disk diskName without registering applications
    delay 2
end tell
" >/dev/null 2>&1 || echo "⚠️ 窗口布局设置跳过（不影响功能）"

sleep 2

# 卸载并压缩
hdiutil detach "$MOUNT_DIR" -quiet

echo "📦 压缩为只读 DMG..."
TEMP_DMG=$(mktemp -u).dmg
hdiutil convert "$DMG_PATH" -format UDZO -imagekey zlib-level=9 -o "$TEMP_DMG"
mv "$TEMP_DMG" "$DMG_PATH"

# 清理
rm -rf "$TMP_DIR"

echo ""
echo "✅ DMG 安装镜像已创建!"
echo "========================================="
echo "📁 位置: $DMG_PATH"
echo ""
echo "用户安装流程:"
echo "1. 双击 ${DMG_NAME}"
echo "2. 将 OTPilot.app 拖到 Applications 文件夹图标"
echo ""
