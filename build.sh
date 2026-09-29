#!/bin/bash
# Build MacLens into a double-clickable .app bundle (no Xcode project needed).
set -euo pipefail
cd "$(dirname "$0")"

APP="MacLens"
BUNDLE="build/$APP.app"
BIN="$BUNDLE/Contents/MacOS/$APP"

echo "▸ Cleaning…"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"

echo "▸ Compiling Swift sources…"
swiftc \
  -O \
  -swift-version 5 \
  -target arm64-apple-macos13.0 \
  -framework SwiftUI -framework AppKit -framework Combine \
  $(find Sources -name '*.swift') \
  -o "$BIN"

echo "▸ Generating app icon…"
SRC_ICON="Assets/AppIcon.png"
if [[ -f "$SRC_ICON" ]]; then
  ICONSET="build/AppIcon.iconset"
  rm -rf "$ICONSET"; mkdir -p "$ICONSET"
  # name:pixels — the standard macOS icon set (16–512 @1x/@2x)
  for entry in \
    icon_16x16:16 icon_16x16@2x:32 \
    icon_32x32:32 icon_32x32@2x:64 \
    icon_128x128:128 icon_128x128@2x:256 \
    icon_256x256:256 icon_256x256@2x:512 \
    icon_512x512:512 icon_512x512@2x:1024 ; do
    name="${entry%%:*}"; px="${entry##*:}"
    sips -z "$px" "$px" "$SRC_ICON" --out "$ICONSET/$name.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$BUNDLE/Contents/Resources/AppIcon.icns"
  echo "  ✓ AppIcon.icns ($(ls "$ICONSET" | wc -l | tr -d ' ') sizes)"
else
  echo "  ⚠ $SRC_ICON not found — skipping icon"
fi

echo "▸ Assembling bundle…"
cp Info.plist "$BUNDLE/Contents/Info.plist"
printf 'APPL????' > "$BUNDLE/Contents/PkgInfo"

echo "▸ Ad-hoc code signing…"
xattr -cr "$BUNDLE" 2>/dev/null || true   # strip iCloud/Finder xattrs that block signing
codesign --force --deep --sign - "$BUNDLE" >/dev/null 2>&1 || true

echo "✓ Built $BUNDLE"
