#!/bin/bash
# Builds Drop Stack.app from the single Swift source file.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
APP="$SRC/build/TailDrop.app"
BIN="$APP/Contents/MacOS/TailDrop"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O \
  -target arm64-apple-macos14.0 \
  -framework AppKit -framework SwiftUI -framework UniformTypeIdentifiers \
  -parse-as-library \
  -o "$BIN" \
  "$SRC/TailDrop.swift"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>TailDrop</string>
  <key>CFBundleDisplayName</key><string>TailDrop</string>
  <key>CFBundleIdentifier</key><string>net.webdevs.taildrop</string>
  <key>CFBundleExecutable</key><string>TailDrop</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key><string>Any</string>
      <key>CFBundleTypeRole</key><string>Viewer</string>
      <key>LSHandlerRank</key><string>None</string>
      <key>LSItemContentTypes</key><array><string>public.item</string></array>
    </dict>
  </array>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP" 2>/dev/null || true
echo "$APP"
