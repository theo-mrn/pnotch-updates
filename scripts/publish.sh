#!/bin/zsh
# Publishes the release built by scripts/release.sh:
#   - the update files (appcast.xml and the signed zip) on GitHub Pages, in theo-mrn/pnotch-updates,
#     where SPARKLE_FEED_URL points, so installed copies find the new version;
#   - the DMG as a GitHub release of the same repository, for first installs.
#
#   scripts/publish.sh
#
# Environment: PNOTCH_UPDATES_REPO (default: theo-mrn/pnotch-updates).
set -euo pipefail

cd "${0:A:h}/.."

REPO="${PNOTCH_UPDATES_REPO:-theo-mrn/pnotch-updates}"
BUILD_DIR="build/release"
UPDATES_DIR="$BUILD_DIR/updates"
SITE_DIR="build/pnotch-updates"
APP="$BUILD_DIR/export/PNotch.app"

fail() {
    print -u2 "✗ $1"
    exit 1
}

step() {
    print "› $1"
}

# MARK: Checks

[[ -d "$APP" ]] || fail "Nothing to publish: run scripts/release.sh first."
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="$BUILD_DIR/PNotch-$VERSION.dmg"
[[ -f "$DMG" ]] || fail "$DMG is missing: run scripts/release.sh again."
[[ -f "$UPDATES_DIR/appcast.xml" ]] || fail "No appcast in $UPDATES_DIR: is SPARKLE_FEED_URL set?"
xcrun stapler validate "$DMG" >/dev/null 2>&1 || fail "$DMG isn't notarized."
command -v gh >/dev/null || fail "The GitHub CLI (gh) is needed: brew install gh, then gh auth login."
gh release view "v$VERSION" --repo "$REPO" >/dev/null 2>&1 \
    && fail "PNotch $VERSION is already published: raise MARKETING_VERSION and CURRENT_PROJECT_VERSION first."

# MARK: Updates, on GitHub Pages

step "Publishing the update files"
if [[ ! -d "$SITE_DIR/.git" ]]; then
    gh repo clone "$REPO" "$SITE_DIR" -- --quiet
fi
git -C "$SITE_DIR" pull --ff-only --quiet
ditto "$UPDATES_DIR" "$SITE_DIR"
git -C "$SITE_DIR" add --all
git -C "$SITE_DIR" commit --quiet -m "PNotch $VERSION"
git -C "$SITE_DIR" push --quiet

# MARK: DMG, as a GitHub release

step "Publishing the DMG"
gh release create "v$VERSION" "$DMG" \
    --repo "$REPO" \
    --title "PNotch $VERSION" \
    --notes "Ouvre le DMG et glisse PNotch dans Applications. Les versions suivantes s'installent ensuite toutes seules.

Open the DMG and drag PNotch to Applications. Later versions then install themselves."

print "✓ PNotch $VERSION is published:"
print "  • https://github.com/$REPO/releases/tag/v$VERSION"
print "  • installed copies will find it within a day, or right away with « Check for Updates… »"
