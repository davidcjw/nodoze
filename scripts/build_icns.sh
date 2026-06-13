#!/bin/bash
# Generate AppIcon.icns from the rendered master PNG.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MASTER="$ROOT/icon_1024.png"
ICONSET="$ROOT/AppIcon.iconset"

swift "$ROOT/scripts/make_icon.swift" "$MASTER"

rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for spec in "16:16x16" "32:16x16@2x" "32:32x32" "64:32x32@2x" \
            "128:128x128" "256:128x128@2x" "256:256x256" "512:256x256@2x" \
            "512:512x512" "1024:512x512@2x"; do
    px="${spec%%:*}"; name="${spec##*:}"
    sips -z "$px" "$px" "$MASTER" --out "$ICONSET/icon_${name}.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$ROOT/AppIcon.icns"
rm -rf "$ICONSET" "$MASTER"
echo "Built $ROOT/AppIcon.icns"
