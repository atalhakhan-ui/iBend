#!/bin/bash
# Regenerates Resources/AppIcon.icns from Tools/make-icon.swift.
set -euo pipefail
cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

swift Tools/make-icon.swift "$TMP/icon_1024.png"
mkdir -p "$TMP/AppIcon.iconset"
for size in 16 32 64 128 256 512 1024; do
  sips -z $size $size "$TMP/icon_1024.png" --out "$TMP/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
done
# Retina variants are the next size up under a @2x name.
for pair in "16 32" "32 64" "128 256" "256 512" "512 1024"; do
  set -- $pair
  cp "$TMP/AppIcon.iconset/icon_${2}x${2}.png" "$TMP/AppIcon.iconset/icon_${1}x${1}@2x.png"
done
rm -f "$TMP/AppIcon.iconset/icon_64x64.png" "$TMP/AppIcon.iconset/icon_1024x1024.png"

iconutil -c icns "$TMP/AppIcon.iconset" -o Resources/AppIcon.icns
echo "wrote Resources/AppIcon.icns"
