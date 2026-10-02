#!/bin/bash
# Builds a Developer ID signed, universal OpenAbi.dmg in ./dist.
#
#   scripts/release.sh                 # sign only
#   NOTARY_PROFILE=OpenAbi scripts/release.sh   # sign + notarize + staple
#
# Create the notary profile once with:
#   xcrun notarytool store-credentials OpenAbi --apple-id <you@example.com> --team-id XQH36L7379
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
BUILD="$ROOT/build/release"
DIST="$ROOT/dist"
IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"
VERSION="$(xcodebuild -project OpenAbi.xcodeproj -target OpenAbi -configuration Release -showBuildSettings 2>/dev/null | awk '/ MARKETING_VERSION = / { print $3 }')"

echo "==> Building OpenAbi $VERSION"
rm -rf "$BUILD" "$DIST"
xcodebuild -project OpenAbi.xcodeproj -scheme OpenAbi -configuration Release \
    -derivedDataPath "$BUILD" \
    ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" \
    OTHER_CODE_SIGN_FLAGS="--timestamp" CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    build | grep -E "error|warning: |BUILD" || true

APP="$BUILD/Build/Products/Release/OpenAbi.app"
codesign --verify --deep --strict --verbose=2 "$APP"

notarize() {
    xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait | tee "$BUILD/notary.log"
    grep -q "status: Accepted" "$BUILD/notary.log"
}

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    # Staple the app itself so it still opens offline after being copied out of the DMG.
    echo "==> Notarizing app"
    ditto -c -k --keepParent "$APP" "$BUILD/OpenAbi.zip"
    notarize "$BUILD/OpenAbi.zip"
    xcrun stapler staple "$APP"
    spctl --assess --type execute --verbose "$APP"
fi

echo "==> Packaging DMG"
mkdir -p "$DIST/dmg"
cp -R "$APP" "$DIST/dmg/"
ln -s /Applications "$DIST/dmg/Applications"
DMG="$DIST/OpenAbi.dmg"
hdiutil create -volname "OpenAbi" -srcfolder "$DIST/dmg" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$DIST/dmg"
codesign --sign "$IDENTITY" --timestamp "$DMG"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    echo "==> Notarizing DMG"
    notarize "$DMG"
    xcrun stapler staple "$DMG"
    spctl --assess --type open --context context:primary-signature --verbose "$DMG"
else
    echo "==> Skipping notarization (set NOTARY_PROFILE to enable)"
fi

shasum -a 256 "$DMG"
echo "==> $DMG"
