#!/bin/bash
set -e

APP="SwiftTrigger"
BUILD="build"
APP_DIR="$BUILD/$APP.app/Contents"

rm -rf "$BUILD"
mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"

SDK=$(xcrun --sdk macosx --show-sdk-path)

swift build -c release 2>&1

cp ".build/release/$APP" "$APP_DIR/MacOS/$APP"
cp Info.plist "$APP_DIR/Info.plist"

# 临时签名（本机运行需要，避免 Gatekeeper 拦截）。
codesign --force --deep --sign - "$BUILD/$APP.app" 2>/dev/null || true

echo "✅ $BUILD/$APP.app"
