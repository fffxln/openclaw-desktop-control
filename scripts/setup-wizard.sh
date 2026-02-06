#!/bin/bash
# Setup Wizard for Desktop Control
# Guided step-by-step setup for first-time users

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_DIR="/Applications"
APP_NAME="DesktopControlHelper"
HELPER="$INSTALL_DIR/$APP_NAME.app/Contents/MacOS/helper"
CLICLICK_DIR="$HOME/.openclaw/bin"

echo ""
echo "🖥️  Desktop Control — Setup Wizard"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "This wizard will set up everything you need to control"
echo "your Mac desktop through OpenClaw."
echo ""

# Check macOS version
MACOS_VERSION=$(sw_vers -productVersion)
MAJOR=$(echo "$MACOS_VERSION" | cut -d. -f1)
if [ "$MAJOR" -lt 14 ]; then
    echo "❌ macOS 14.0 (Sonoma) or later is required."
    echo "   You are running macOS $MACOS_VERSION."
    echo "   Please update your Mac and run this wizard again."
    exit 1
fi
echo "✅ macOS $MACOS_VERSION"
echo ""

# Step 1: Install helper
echo "━━━ Step 1/4: Install Desktop Control Helper ━━━"
echo ""

if [ -f "$HELPER" ]; then
    echo "✅ Already installed."
else
    echo "Installing..."
    bash "$SCRIPT_DIR/install.sh" 2>/dev/null
    if [ -f "$HELPER" ]; then
        echo "✅ Installed."
    else
        echo "❌ Installation failed. Please check the error above."
        exit 1
    fi
fi
echo ""

# Step 2: Install cliclick
echo "━━━ Step 2/4: Install cliclick (mouse/keyboard control) ━━━"
echo ""

CLICLICK_OK=false
if command -v cliclick &> /dev/null; then
    echo "✅ cliclick found in PATH."
    CLICLICK_OK=true
elif [ -f "$CLICLICK_DIR/cliclick" ]; then
    echo "✅ cliclick found at $CLICLICK_DIR/cliclick."
    CLICLICK_OK=true
elif [ -f "$SKILL_DIR/bin/cliclick" ]; then
    mkdir -p "$CLICLICK_DIR"
    cp "$SKILL_DIR/bin/cliclick" "$CLICLICK_DIR/cliclick"
    chmod +x "$CLICLICK_DIR/cliclick"
    echo "✅ Bundled cliclick installed."
    CLICLICK_OK=true
fi

if [ "$CLICLICK_OK" = false ]; then
    echo "cliclick is not installed. It's needed for mouse and keyboard control."
    echo ""
    if command -v brew &> /dev/null; then
        read -p "Install cliclick via Homebrew? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            brew install cliclick
            echo "✅ cliclick installed."
        else
            echo "⚠️  Skipped. Mouse/keyboard control will not work."
            echo "   Install later with: brew install cliclick"
        fi
    else
        echo "⚠️  Homebrew not found. Install cliclick manually:"
        echo "   1. Install Homebrew: https://brew.sh"
        echo "   2. Run: brew install cliclick"
    fi
fi
echo ""

# Step 3: Screen Recording permission
echo "━━━ Step 3/4: Grant Screen Recording permission ━━━"
echo ""

ATTEMPTS=0
while [ $ATTEMPTS -lt 3 ]; do
    if "$HELPER" check-permissions 2>&1 | grep -q "Screen Recording permission granted"; then
        echo "✅ Screen Recording permission granted."
        break
    fi

    if [ $ATTEMPTS -eq 0 ]; then
        echo "Screen Recording permission is needed to capture screenshots."
        echo ""
        echo "Opening System Settings..."
        open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        sleep 1
        echo ""
        echo "In System Settings:"
        echo "  1. Find 'DesktopControlHelper' or 'OpenClaw Desktop Control Helper'"
        echo "  2. Toggle it ON"
        echo "  3. If prompted, click 'Quit & Reopen' or enter your password"
    fi

    echo ""
    read -p "Press Enter when you've enabled Screen Recording... "
    ((ATTEMPTS++))

    if "$HELPER" check-permissions 2>&1 | grep -q "Screen Recording permission granted"; then
        echo "✅ Screen Recording permission granted."
        break
    else
        if [ $ATTEMPTS -lt 3 ]; then
            echo "⚠️  Not detected yet. Make sure the toggle is ON and try again."
        else
            echo "⚠️  Could not verify Screen Recording permission."
            echo "   You can grant it later in System Settings > Privacy & Security > Screen Recording."
        fi
    fi
done
echo ""

# Step 4: Accessibility permission
echo "━━━ Step 4/4: Grant Accessibility permission ━━━"
echo ""

ATTEMPTS=0
while [ $ATTEMPTS -lt 3 ]; do
    if "$HELPER" check-permissions 2>&1 | grep -q "Accessibility permission granted"; then
        echo "✅ Accessibility permission granted."
        break
    fi

    if [ $ATTEMPTS -eq 0 ]; then
        echo "Accessibility permission is needed for mouse and keyboard control."
        echo ""
        echo "Opening System Settings..."
        open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        sleep 1
        echo ""
        echo "In System Settings:"
        echo "  1. Find 'DesktopControlHelper' or 'OpenClaw Desktop Control Helper'"
        echo "  2. Toggle it ON"
        echo "  3. If prompted, enter your password"
    fi

    echo ""
    read -p "Press Enter when you've enabled Accessibility... "
    ((ATTEMPTS++))

    if "$HELPER" check-permissions 2>&1 | grep -q "Accessibility permission granted"; then
        echo "✅ Accessibility permission granted."
        break
    else
        if [ $ATTEMPTS -lt 3 ]; then
            echo "⚠️  Not detected yet. Make sure the toggle is ON and try again."
        else
            echo "⚠️  Could not verify Accessibility permission."
            echo "   You can grant it later in System Settings > Privacy & Security > Accessibility."
        fi
    fi
done

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if "$HELPER" check-permissions &> /dev/null; then
    echo "🎉 Setup complete! Desktop control is ready to use."
    echo ""
    echo "Quick test:"
    echo "  $SCRIPT_DIR/desktop-control screencapture -x /tmp/test.png"
else
    echo "⚠️  Setup partially complete. Some permissions are still missing."
    echo "   Open System Settings > Privacy & Security to grant them."
fi
