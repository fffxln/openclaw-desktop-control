#!/bin/bash
# setup_check.sh — Verify all prerequisites for desktop-control skill

echo "=== Desktop Control: Setup Check ==="
echo ""

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="/Applications/DesktopControlHelper.app/Contents/MacOS/helper"

check() {
  if eval "$2" > /dev/null 2>&1; then
    echo "✅ $1"
    ((PASS++))
  else
    echo "❌ $1 — $3"
    ((FAIL++))
  fi
}

# macOS version check
MACOS_VERSION=$(sw_vers -productVersion)
MAJOR=$(echo "$MACOS_VERSION" | cut -d. -f1)
if [ "$MAJOR" -ge 14 ]; then
  echo "✅ macOS $MACOS_VERSION (14.0+ required)"
  ((PASS++))
else
  echo "❌ macOS $MACOS_VERSION — macOS 14.0 (Sonoma) or later required"
  ((FAIL++))
fi

# Core tools
check "cliclick" "command -v cliclick || [ -f $HOME/.openclaw/bin/cliclick ]" "Run: brew install cliclick"
check "osascript" "which osascript" "Built into macOS — should always be present"

# Check for Desktop Control Helper
echo ""
echo "--- Desktop Control Helper ---"
if [ -f "$HELPER" ]; then
  echo "✅ Desktop Control Helper installed"
  ((PASS++))
  ARCH=$(file "$HELPER" | grep -c "universal")
  if [ "$ARCH" -gt 0 ]; then
    echo "   Universal binary (arm64 + x86_64)"
  fi
else
  echo "❌ Desktop Control Helper not found"
  echo "   → Run: bash $SCRIPT_DIR/scripts/install.sh"
  ((FAIL++))
fi

# Permissions (via Desktop Control Helper if installed)
echo ""
echo "--- Permission Checks ---"

if [ -f "$HELPER" ]; then
  if "$HELPER" check-permissions 2>&1; then
    ((PASS+=2))
  else
    ((FAIL+=2))
    echo ""
    echo "To grant permissions, run:"
    echo "  bash $SCRIPT_DIR/scripts/setup-wizard.sh"
  fi
else
  echo "⚠️  Cannot check permissions — helper not installed"
  echo "   Run: bash $SCRIPT_DIR/scripts/setup-wizard.sh"
  ((FAIL+=2))
fi

# Display info
echo ""
echo "--- Display Info ---"
RESOLUTION=$(osascript -e 'tell application "Finder" to get bounds of window of desktop' 2>/dev/null || echo "unknown")
SCALE=$(system_profiler SPDisplaysDataType 2>/dev/null | grep "Resolution" | head -1 | sed 's/^[[:space:]]*//')
echo "Desktop bounds: $RESOLUTION"
echo "Display: $SCALE"
if [ -f "$HELPER" ]; then
  FACTOR=$("$HELPER" get-scale-factor 2>/dev/null || echo "unknown")
  echo "Scale factor: ${FACTOR}x"
fi

# Summary
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -eq 0 ]; then
  echo "🦞 All good — desktop control is ready."
else
  echo "⚠️  Fix the issues above, or run: bash $SCRIPT_DIR/scripts/setup-wizard.sh"
fi

exit $FAIL
