#!/bin/zsh
# Builds, signs with Developer ID, notarizes and packages PNotch, then updates the Sparkle appcast.
#
#   scripts/release.sh
#
# One-time setup, see README › Distribution:
#   1. A "Developer ID Application" certificate (Xcode › Settings › Accounts › Manage Certificates).
#   2. Notarization credentials stored under a keychain profile (PNotch by default):
#        xcrun notarytool store-credentials PNotch --apple-id <apple id> --team-id CLFGDZUD7W
#   3. Sparkle signing keys, and the feed URL and public key in Configuration/Distribution.xcconfig.
#
# Environment: NOTARY_PROFILE (default: PNotch).
set -euo pipefail

cd "${0:A:h}/.."

NOTARY_PROFILE="${NOTARY_PROFILE:-PNotch}"
BUILD_DIR="build/release"
ARCHIVE="$BUILD_DIR/PNotch.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
UPDATES_DIR="$BUILD_DIR/updates"
PACKAGES_DIR="$BUILD_DIR/SourcePackages"

fail() {
    print -u2 "✗ $1"
    exit 1
}

step() {
    print "› $1"
}

# MARK: Prerequisites

security find-identity -v -p codesigning | grep -q "Developer ID Application" \
    || fail "No \"Developer ID Application\" certificate in the keychain. Create one in Xcode › Settings › Accounts › Manage Certificates."
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
    || fail "No notarization credentials under the \"$NOTARY_PROFILE\" profile. Run: xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id <apple id> --team-id CLFGDZUD7W"

feed_url=$(sed -nE 's/^SPARKLE_FEED_URL *= *(.*)$/\1/p' Configuration/Distribution.xcconfig)
# The xcconfig writes `https:/$()/…` so its slashes aren't read as a comment.
feed_url=${feed_url//\$\(\)/}
[[ -n "$feed_url" ]] || print "⚠︎ SPARKLE_FEED_URL is empty: this build won't check for updates."

# MARK: Build

rm -rf "$ARCHIVE" "$EXPORT_DIR"
mkdir -p "$UPDATES_DIR"

step "Archiving"
xcodebuild archive \
    -project PNotch.xcodeproj \
    -scheme PNotch \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$ARCHIVE" \
    -clonedSourcePackagesDirPath "$PACKAGES_DIR" \
    -quiet

step "Exporting with Developer ID"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist Configuration/ExportOptions.plist \
    -quiet

APP="$EXPORT_DIR/PNotch.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Contents/Info.plist")

# MARK: Notarization

step "Notarizing PNotch $VERSION ($BUILD_NUMBER)"
ditto -c -k --keepParent "$APP" "$BUILD_DIR/notarization.zip"
xcrun notarytool submit "$BUILD_DIR/notarization.zip" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
spctl --assess --type execute "$APP" || fail "Gatekeeper rejects the notarized app."

# MARK: Packages

step "Packaging"
ZIP="$UPDATES_DIR/PNotch-$VERSION.zip"
DMG="$BUILD_DIR/PNotch-$VERSION.dmg"
ditto -c -k --keepParent "$APP" "$ZIP"

# The app next to a link to Applications: open the DMG, drag one onto the other.
DMG_ROOT="$BUILD_DIR/dmg"
rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"
ditto "$APP" "$DMG_ROOT/PNotch.app"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create -volname PNotch -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG" -quiet
rm -rf "$DMG_ROOT"
codesign --sign "Developer ID Application" --timestamp "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"

# MARK: Appcast

if [[ -n "$feed_url" ]]; then
    step "Updating the appcast"
    sparkle_bin=$(find "$PACKAGES_DIR/artifacts" -type d -path "*Sparkle/bin" | head -1)
    [[ -n "$sparkle_bin" ]] || fail "Sparkle's tools were not found in $PACKAGES_DIR."
    # Signs the archive with the EdDSA key stored in the keychain by generate_keys.
    "$sparkle_bin/generate_appcast" --download-url-prefix "${feed_url%/*}/" "$UPDATES_DIR"
fi

print "✓ PNotch $VERSION is ready:"
print "  • $DMG — to share for a first install"
[[ -n "$feed_url" ]] && print "  • $UPDATES_DIR — to upload next to ${feed_url}"
