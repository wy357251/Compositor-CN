#!/bin/zsh
# Builds dist/Compositor-<version>-unsigned.dmg: a Release build signed ad-hoc, with no Developer ID and no
# notarization, so it costs nothing to produce but Gatekeeper stops it on other people's Macs.
#
# For a DMG that opens without warnings, use scripts/release.sh instead — it needs an Apple Developer account.
#
# What a recipient has to do once, after downloading:
#   xattr -dr com.apple.quarantine "/Applications/Compositor.app"
# or right-click the app in Finder and choose Open. See the README.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP=Compositor
WORK="$HOME/Library/Caches/CompositorUnsigned"
DIST="$PROJECT_DIR/dist"

settings=$(xcodebuild -project "$PROJECT_DIR/$APP.xcodeproj" -scheme "$APP" -configuration Release -showBuildSettings 2>/dev/null)
VERSION=$(print -r -- "$settings" | awk -F' = ' '/ MARKETING_VERSION = /{print $2; exit}')
BUILD=$(print -r -- "$settings" | awk -F' = ' '/ CURRENT_PROJECT_VERSION = /{print $2; exit}')
echo "==> $APP $VERSION ($BUILD), unsigned"

rm -rf "$WORK"
mkdir -p "$WORK" "$DIST"

echo "==> Building Release, signed ad-hoc"
# Manual style with the ad-hoc identity, so the Release configuration's Developer ID team is not consulted.
xcodebuild build -quiet \
  -project "$PROJECT_DIR/$APP.xcodeproj" -scheme "$APP" -configuration Release \
  -destination "generic/platform=macOS" -derivedDataPath "$WORK/DerivedData" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=

APP_PATH="$WORK/DerivedData/Build/Products/Release/$APP.app"
[[ -d "$APP_PATH" ]] || { echo "No $APP_PATH — the build did not produce it."; exit 1; }
codesign --verify --strict --verbose=1 "$APP_PATH"

echo "==> Checking the resources made it in"
# The Chinese UI is the point of this fork; a DMG that ships without it is a silent regression.
[[ -d "$APP_PATH/Contents/Resources/zh-Hans.lproj" ]] || { echo "zh-Hans.lproj is missing from the build."; exit 1; }
echo "    zh-Hans.lproj present"

echo "==> Building the DMG"
STAGE="$WORK/dmg"
mkdir -p "$STAGE"
cp -R "$APP_PATH" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
DMG="$DIST/$APP-$VERSION-unsigned.dmg"
rm -f "$DMG"
hdiutil create -quiet -volname "$APP" -srcfolder "$STAGE" -ov -format UDZO "$DMG"

echo "==> $DMG"
du -h "$DMG" | awk '{print "    " $1}'
echo "==> Gatekeeper's verdict. spctl rejects an ad-hoc build even here; it still launches on this Mac because a"
echo "    locally built app carries no quarantine attribute — a downloaded copy gets both problems at once."
spctl --assess --type execute --verbose=1 "$APP_PATH" 2>&1 | tail -2 || true
cat <<'NOTE'

Distributing an unsigned build: the recipient's Mac adds a quarantine attribute to anything
downloaded from a browser, and Gatekeeper refuses it. They clear it once with

    xattr -dr com.apple.quarantine "/Applications/Compositor.app"

or by right-clicking the app in Finder and choosing Open. Say so wherever the DMG is linked —
without it most people will assume the download is broken.
NOTE
