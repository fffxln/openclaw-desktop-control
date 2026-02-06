#!/bin/bash
# Installation script for Desktop Control Helper
# Copies the pre-built helper app and bundled cliclick to ~/.openclaw/bin/
# Falls back to building from source if pre-built binary is missing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_DIR="$HOME/.openclaw/bin"
APP_NAME="DesktopControlHelper"

echo "📦 Installing Desktop Control Helper..."
echo ""

# Check macOS version (requires 14.0+ for ScreenCaptureKit's SCScreenshotManager)
MACOS_VERSION=$(sw_vers -productVersion)
MAJOR=$(echo "$MACOS_VERSION" | cut -d. -f1)
if [ "$MAJOR" -lt 14 ]; then
    echo "❌ macOS 14.0 (Sonoma) or later is required."
    echo "   You are running macOS $MACOS_VERSION."
    exit 1
fi

# Create installation directory
mkdir -p "$INSTALL_DIR"

# Step 1: Install the helper app
echo "1️⃣  Installing helper app..."

if [ -f "$SKILL_DIR/bin/$APP_NAME.app/Contents/MacOS/helper" ]; then
    # Use pre-built binary
    if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
        rm -rf "$INSTALL_DIR/$APP_NAME.app"
    fi
    cp -R "$SKILL_DIR/bin/$APP_NAME.app" "$INSTALL_DIR/"
    xattr -cr "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null || true
    codesign --force --sign - --identifier "ai.openclaw.desktop-control-helper" "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null || true
    echo "   Installed pre-built helper."
else
    # Fallback: build from source
    echo "   Pre-built binary not found. Building from source..."
    bash "$SCRIPT_DIR/build.sh"
    if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
        rm -rf "$INSTALL_DIR/$APP_NAME.app"
    fi
    cp -R "$SKILL_DIR/bin/$APP_NAME.app" "$INSTALL_DIR/"
fi

# Verify helper installed
if [ ! -f "$INSTALL_DIR/$APP_NAME.app/Contents/MacOS/helper" ]; then
    echo "❌ Installation failed: helper binary not found"
    exit 1
fi
echo "   ✅ Helper installed."

# Step 2: Install cliclick
echo ""
echo "2️⃣  Checking cliclick..."

if command -v cliclick &> /dev/null; then
    echo "   ✅ cliclick found in PATH."
elif [ -f "$INSTALL_DIR/cliclick" ]; then
    echo "   ✅ cliclick found at $INSTALL_DIR/cliclick."
elif [ -f "$SKILL_DIR/bin/cliclick" ]; then
    cp "$SKILL_DIR/bin/cliclick" "$INSTALL_DIR/cliclick"
    chmod +x "$INSTALL_DIR/cliclick"
    echo "   ✅ Bundled cliclick installed to $INSTALL_DIR/cliclick."
else
    echo "   ⚠️  cliclick not found."
    echo "   cliclick is required for mouse and keyboard control."
    echo "   Install with: brew install cliclick"
fi

# Step 3: Check permissions
echo ""
echo "3️⃣  Checking permissions..."
HELPER="$INSTALL_DIR/$APP_NAME.app/Contents/MacOS/helper"
if "$HELPER" check-permissions 2>&1; then
    echo ""
    echo "🎉 Installation complete! Desktop control is ready."
else
    echo ""
    echo "⚠️  Permissions required. Run the setup wizard for guided setup:"
    echo "   bash $SCRIPT_DIR/setup-wizard.sh"
    echo ""
    echo "Or grant manually in System Settings > Privacy & Security:"
    echo "   - Screen Recording → enable DesktopControlHelper"
    echo "   - Accessibility → enable DesktopControlHelper"
fi

echo ""
echo "Helper: $INSTALL_DIR/$APP_NAME.app"
