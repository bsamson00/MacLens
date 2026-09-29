#!/bin/bash
# Build a distributable .dmg with a styled drag-to-Applications layout.
# Uses create-dmg (brew install create-dmg) for reliable window/background handling.
set -euo pipefail
cd "$(dirname "$0")"

APP="MacLens"
VERSION="1.5"
# Overridable so notarize.sh can stage outside iCloud (avoids xattr issues).
SRC_APP="${SRC_APP:-build/$APP.app}"
DMG="${OUT_DMG:-build/$APP-$VERSION.dmg}"
APP_BASENAME="$(basename "$SRC_APP")"

# Ensure the app exists (build only when using the default in-tree path).
if [[ ! -d "$SRC_APP" ]]; then
  if [[ "$SRC_APP" == "build/$APP.app" ]]; then
    echo "▸ App not built yet — running build.sh…"; ./build.sh
  else
    echo "✗ App not found at $SRC_APP"; exit 1
  fi
fi

# Regenerate the styled background (1x + @2x retina).
if [[ -f "Assets/dmg-background.swift" ]]; then
  echo "▸ Rendering background…"
  swift Assets/dmg-background.swift
fi

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "✗ create-dmg not found. Install it with:  brew install create-dmg"
  exit 1
fi

echo "▸ Building DMG…"
rm -f "$DMG"
hdiutil detach "/Volumes/$APP" >/dev/null 2>&1 || true

# Sign the disk image too if a Developer ID is present.
SIGN_ARGS=()
if security find-identity -v -p codesigning 2>/dev/null | grep -q "Developer ID Application"; then
  SIGN_ID=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 \
            | sed -E 's/.*"(.*)"/\1/')
  SIGN_ARGS=(--codesign "$SIGN_ID")
fi

create-dmg \
  --volname "$APP" \
  --background "Assets/dmg-background.png" \
  --window-pos 320 180 \
  --window-size 560 380 \
  --icon-size 112 \
  --icon "$APP_BASENAME" 150 195 \
  --hide-extension "$APP_BASENAME" \
  --app-drop-link 410 195 \
  --no-internet-enable \
  "${SIGN_ARGS[@]}" \
  "$DMG" \
  "$SRC_APP"

echo "✓ Built $DMG ($(du -h "$DMG" | awk '{print $1}'))"
