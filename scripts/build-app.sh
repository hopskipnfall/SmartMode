#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/SmartMode"

VERSION="$(tr -d '[:space:]' < VERSION)"
BUILD="$(git rev-parse --short HEAD 2>/dev/null || echo dev)"

APP="SmartMode.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/SmartMode"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>local.smartmode</string>
  <key>CFBundleName</key><string>SmartMode</string>
  <key>CFBundleExecutable</key><string>SmartMode</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>Copyright © 2026 hopskipnfall. Apache License 2.0.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>Smart Mode switches between light and dark appearance.</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP — run with: open $APP"
