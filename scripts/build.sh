#!/bin/bash
# Build script for Desktop Control Helper
# Compiles Swift source into a proper .app bundle with TCC entitlements
# Produces a universal binary (arm64 + x86_64) for all Mac hardware

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$SKILL_DIR/src"
BUILD_DIR="$SKILL_DIR/bin"
APP_NAME="DesktopControlHelper"
TEMP_DIR="$BUILD_DIR/.build-temp"

echo "🔨 Building Desktop Control Helper..."

# Check for Swift compiler
if ! command -v swiftc &> /dev/null; then
    echo "❌ Swift compiler not found."
    echo "   Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "   Please run this script again after installation completes."
    exit 1
fi

# Create build directory structure
mkdir -p "$BUILD_DIR/$APP_NAME.app/Contents/MacOS"
mkdir -p "$BUILD_DIR/$APP_NAME.app/Contents/Resources"
mkdir -p "$TEMP_DIR"

SWIFT_FLAGS="-O -swift-version 5 \
    -framework AppKit \
    -framework CoreGraphics \
    -framework ScreenCaptureKit \
    -framework ImageIO \
    -framework ApplicationServices"

# Build arm64
echo "   Compiling helper.swift (arm64)..."
swiftc $SWIFT_FLAGS \
    -target arm64-apple-macos14.0 \
    -o "$TEMP_DIR/helper-arm64" \
    "$SRC_DIR/helper.swift"

# Build x86_64
echo "   Compiling helper.swift (x86_64)..."
swiftc $SWIFT_FLAGS \
    -target x86_64-apple-macos14.0 \
    -o "$TEMP_DIR/helper-x86_64" \
    "$SRC_DIR/helper.swift"

# Merge into universal binary
echo "   Creating universal binary..."
lipo -create \
    "$TEMP_DIR/helper-arm64" \
    "$TEMP_DIR/helper-x86_64" \
    -output "$BUILD_DIR/$APP_NAME.app/Contents/MacOS/helper"

# Clean up temp files
rm -rf "$TEMP_DIR"

# Create Info.plist
echo "   Creating Info.plist..."
cat > "$BUILD_DIR/$APP_NAME.app/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>helper</string>
    <key>CFBundleIdentifier</key>
    <string>ai.openclaw.desktop-control-helper</string>
    <key>CFBundleName</key>
    <string>DesktopControlHelper</string>
    <key>CFBundleDisplayName</key>
    <string>OpenClaw Desktop Control Helper</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>OpenClaw Desktop Control needs to control your computer to automate desktop tasks like clicking, typing, and navigating apps.</string>
    <key>NSSystemAdministrationUsageDescription</key>
    <string>OpenClaw Desktop Control needs administrative access for system-level automation.</string>
</dict>
</plist>
EOF

# Make executable
chmod +x "$BUILD_DIR/$APP_NAME.app/Contents/MacOS/helper"

# Ad-hoc sign the bundle
echo "   Signing..."
xattr -cr "$BUILD_DIR/$APP_NAME.app" 2>/dev/null || true
codesign --force --sign - --identifier "ai.openclaw.desktop-control-helper" "$BUILD_DIR/$APP_NAME.app"

echo "✅ Build complete: $BUILD_DIR/$APP_NAME.app"
file "$BUILD_DIR/$APP_NAME.app/Contents/MacOS/helper"
