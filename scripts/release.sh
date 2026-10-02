#!/bin/bash
# Builds a Developer ID signed, universal OpenAbi.dmg in ./dist and, when notarized,
# signs it for Sparkle and writes docs/appcast.xml (the update feed served by GitHub Pages).
#
# Before each release bump MARKETING_VERSION and CURRENT_PROJECT_VERSION (Sparkle compares the
# build number), and add docs/release-notes/<version>.html.
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
SETTINGS="$(xcodebuild -project OpenAbi.xcodeproj -target OpenAbi -configuration Release -showBuildSettings 2>/dev/null)"
VERSION="$(awk '/ MARKETING_VERSION = / { print $3 }' <<<"$SETTINGS")"
BUILD_NUMBER="$(awk '/ CURRENT_PROJECT_VERSION = / { print $3 }' <<<"$SETTINGS")"
SPARKLE_BIN="$BUILD/SourcePackages/artifacts/sparkle/Sparkle/bin"
REPO_URL="https://github.com/firatmelih/OpenAbi"
PAGES_URL="https://firatmelih.github.io/OpenAbi"

echo "==> Building OpenAbi $VERSION"
rm -rf "$BUILD" "$DIST"
xcodebuild -project OpenAbi.xcodeproj -scheme OpenAbi -configuration Release \
    -derivedDataPath "$BUILD" \
    ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" \
    OTHER_CODE_SIGN_FLAGS="--timestamp" CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    build | grep -E "error|warning: |BUILD" || true

APP="$BUILD/Build/Products/Release/OpenAbi.app"

# Sparkle's helpers must carry our Developer ID, hardened runtime and a timestamp to pass notarization.
echo "==> Re-signing Sparkle"
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
sign() { codesign --force --sign "$IDENTITY" --options runtime --timestamp "$@"; }
sign "$SPARKLE/Versions/B/XPCServices/Installer.xpc"
sign --preserve-metadata=entitlements "$SPARKLE/Versions/B/XPCServices/Downloader.xpc"
sign "$SPARKLE/Versions/B/Autoupdate"
sign "$SPARKLE/Versions/B/Updater.app"
sign "$SPARKLE"
sign --entitlements Config/OpenAbi.entitlements "$APP"
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

    echo "==> Writing docs/appcast.xml"
    ENCLOSURE_SIGNATURE="$("$SPARKLE_BIN/sign_update" --account OpenAbi "$DMG")"
    cat > docs/appcast.xml <<APPCAST
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>OpenAbi</title>
    <link>$PAGES_URL/appcast.xml</link>
    <item>
      <title>OpenAbi $VERSION</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$BUILD_NUMBER</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>$PAGES_URL/release-notes/$VERSION.html</sparkle:releaseNotesLink>
      <enclosure url="$REPO_URL/releases/download/v$VERSION/OpenAbi.dmg" type="application/octet-stream" $ENCLOSURE_SIGNATURE />
    </item>
  </channel>
</rss>
APPCAST
    [[ -f "docs/release-notes/$VERSION.html" ]] || echo "!! Missing docs/release-notes/$VERSION.html"
    echo "==> Next: gh release create v$VERSION dist/OpenAbi.dmg, then commit and push docs/appcast.xml"
else
    echo "==> Skipping notarization and appcast (set NOTARY_PROFILE to enable)"
fi

shasum -a 256 "$DMG"
echo "==> $DMG"
