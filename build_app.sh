#!/bin/bash
set -e

EXEC="SwiftTrigger"        # 可执行文件名（必须 ASCII，与 CFBundleExecutable 一致）
APP_NAME="快触发器"         # .app 包显示名
BUILD="build"
APP_DIR="$BUILD/$APP_NAME.app/Contents"

rm -rf "$BUILD"
mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"

swift build -c release 2>&1

cp ".build/release/$EXEC" "$APP_DIR/MacOS/$EXEC"
cp Info.plist "$APP_DIR/Info.plist"
cp AppIcon.icns "$APP_DIR/Resources/AppIcon.icns"

# 临时签名（本机运行需要，避免 Gatekeeper 拦截）。
codesign --force --deep --sign - "$BUILD/$APP_NAME.app" 2>/dev/null || true

echo "✅ $BUILD/$APP_NAME.app"
