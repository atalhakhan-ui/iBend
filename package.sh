#!/bin/bash
# Builds a release app and wraps it in a drag-to-install disk image.
set -euo pipefail
cd "$(dirname "$0")"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
DMG="dist/iBend-${VERSION}.dmg"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

./build.sh release

mkdir -p dist
cp -R build/iBend.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create -volname "iBend" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

echo "$DMG  ($(du -h "$DMG" | cut -f1))"
