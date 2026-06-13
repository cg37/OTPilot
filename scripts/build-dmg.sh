#!/bin/bash
set -e

# OTPilot DMG Builder
# Usage: ./scripts/build-dmg.sh [version]

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="OTPilot"
VERSION="${1:-1.0.0}"
DMG_NAME="${APP_NAME}-${VERSION}"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"
DMG_DIR="$BUILD_DIR/dmg"
DMG_FILE="$BUILD_DIR/${DMG_NAME}.dmg"

echo "🔨 编译 ${APP_NAME} v${VERSION}..."
echo "========================================="

# Clean and prepare build directory
rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy Info.plist
cp "$SCRIPT_DIR/${APP_NAME}.app/Contents/Info.plist" "$APP_BUNDLE/Contents/"

# Update version in Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true

# Compile Swift sources
swiftc -target arm64-apple-macos13 \
    -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
    "$SCRIPT_DIR/Sources/"*.swift \
    -framework AppKit \
    -framework UserNotifications \
    -lsqlite3

echo "✅ 编译完成"
echo ""

# Create DMG staging directory
echo "📦 打包 DMG..."
mkdir -p "$DMG_DIR"
cp -R "$APP_BUNDLE" "$DMG_DIR/"

# Create symlink to /Applications
ln -s /Applications "$DMG_DIR/Applications"

# Create DMG
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "$DMG_FILE"

# Clean up staging
rm -rf "$DMG_DIR"

echo ""
echo "✅ DMG 已生成: $DMG_FILE"
echo "   大小: $(du -sh "$DMG_FILE" | cut -f1)"
