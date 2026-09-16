#!/bin/bash
# Builds iBend.app from the SwiftPM executable and ad-hoc signs it so that
# login-item registration and TCC have a stable identity to attach to.
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-release}"
APP="build/iBend.app"

swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/iBend"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/iBend"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$APP/Contents/Resources/"; fi

codesign --force --sign - --timestamp=none "$APP" >/dev/null 2>&1 || \
  echo "note: ad-hoc signing failed; the app still runs but Launch at Login may not stick"

echo "built $APP"
