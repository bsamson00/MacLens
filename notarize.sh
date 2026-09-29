#!/bin/bash
# Sign (Developer ID + hardened runtime), build the DMG, notarize it with Apple,
# and staple the ticket so MacLens opens with no Gatekeeper warning anywhere.
#
# One-time credential setup (pick ONE), then this script just works:
#   A) App-specific password (easiest):
#        xcrun notarytool store-credentials "maclens-notary" \
#          --apple-id "you@example.com" --team-id "ECAL4Y29X5"
#        # paste an app-specific password from https://account.apple.com → Sign-In & Security
#   B) App Store Connect API key:
#        xcrun notarytool store-credentials "maclens-notary" \
#          --key AuthKey_XXXX.p8 --key-id KEYID --issuer ISSUER-UUID
#
# Override the profile name with NOTARY_PROFILE=... if you named it differently.
set -euo pipefail
cd "$(dirname "$0")"

APP="MacLens"
VERSION="1.5"
DMG="build/$APP-$VERSION.dmg"
PROFILE="${NOTARY_PROFILE:-maclens-notary}"
TEAM_ID="ECAL4Y29X5"

ID=$(security find-identity -v -p codesigning 2>/dev/null \
     | grep "Developer ID Application" | head -1 | sed -E 's/.*"(.*)"/\1/')
if [[ -z "$ID" ]]; then
  echo "✗ No 'Developer ID Application' certificate found in the keychain."; exit 1
fi
echo "▸ Signing identity: $ID"

# 1) Build (if needed), then stage OUTSIDE iCloud so xattrs don't reappear mid-sign.
[[ -d "build/$APP.app" ]] || ./build.sh
WORK="$(mktemp -d /tmp/maclens-notary.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
echo "▸ Staging in $WORK..."
ditto --norsrc --noextattr "build/$APP.app" "$WORK/$APP.app"

echo "▸ Signing app (Developer ID + hardened runtime)..."
xattr -cr "$WORK/$APP.app" 2>/dev/null || true
codesign --force --options runtime --timestamp --deep --sign "$ID" "$WORK/$APP.app"
codesign --verify --strict --verbose=2 "$WORK/$APP.app"

# 2) Package into the signed DMG (built in the work dir; copied back once stapled).
echo "▸ Building DMG..."
WDMG="$WORK/$(basename "$DMG")"
SRC_APP="$WORK/$APP.app" OUT_DMG="$WDMG" ./make-dmg.sh

# 3) Notarize. Requires the credential profile described at the top of this script.
if ! xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
  echo
  echo "✗ Notary credentials profile '$PROFILE' not found."
  echo "  Set it up once with (team id is $TEAM_ID):"
  echo "    xcrun notarytool store-credentials \"$PROFILE\" --apple-id \"YOUR_APPLE_ID\" --team-id \"$TEAM_ID\""
  echo "  then re-run ./notarize.sh"
  exit 1
fi

echo "▸ Submitting to Apple notary service (this can take a few minutes)..."
xcrun notarytool submit "$WDMG" --keychain-profile "$PROFILE" --wait

# 4) Staple the ticket onto the DMG so it validates offline, then copy back.
echo "▸ Stapling ticket..."
xcrun stapler staple "$WDMG"
xcrun stapler validate "$WDMG"
cp "$WDMG" "$DMG"

# 5) Final Gatekeeper check.
echo "▸ Gatekeeper assessment:"
spctl -a -t open --context context:primary-signature -v "$WDMG" || true

echo "✓ Notarized & stapled: $DMG"
