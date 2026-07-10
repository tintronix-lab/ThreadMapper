#!/usr/bin/env bash
# Builds, installs, launches ThreadMapper on an iOS simulator and takes screenshots.
# Usage: ./smoke.sh [sim-udid] [screenshot-dir]
# Defaults: iPhone 17 Pro (EF810E05-C12F-468D-9F55-4131492332E8), /tmp/threadmapper-screenshots

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SIM_UDID="${1:-EF810E05-C12F-468D-9F55-4131492332E8}"
SCREENSHOT_DIR="${2:-/tmp/threadmapper-screenshots}"
BUNDLE_ID="com.tintronixlab.ThreadMapper"
DERIVED_DATA="$REPO_ROOT/build/DerivedDataSim"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/ThreadMapper.app"

mkdir -p "$SCREENSHOT_DIR"

step() { echo "▶ $*"; }

# 1. Regenerate xcodeproj — stale when files are added/renamed
step "Regenerating xcodeproj (xcodegen)…"
cd "$REPO_ROOT"
xcodegen generate

# 2. Build for simulator
step "Building for simulator ($SIM_UDID)…"
xcrun xcodebuild \
  -project "$REPO_ROOT/ThreadMapper.xcodeproj" \
  -scheme ThreadMapper \
  -destination "id=$SIM_UDID" \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | tail -5

# 3. Boot simulator (no-op if already booted)
step "Booting simulator…"
xcrun simctl boot "$SIM_UDID" 2>/dev/null || true
sleep 3

# 4. Install & launch
step "Installing…"
xcrun simctl install "$SIM_UDID" "$APP_PATH"

step "Launching…"
xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID"
sleep 4

# 5. Screenshot — Dashboard (initial screen)
SHOT1="$SCREENSHOT_DIR/01_dashboard.png"
xcrun simctl io "$SIM_UDID" screenshot "$SHOT1"
step "Screenshot saved: $SHOT1"

echo "✅ Done. Screenshots in $SCREENSHOT_DIR"
