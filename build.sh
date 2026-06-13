#!/bin/bash
# Build NoDoze.app from the Swift sources. No Xcode project required.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/NoDoze.app"
BIN_DIR="$APP/Contents/MacOS"

rm -rf "$APP"
mkdir -p "$BIN_DIR" "$APP/Contents/Resources"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"

# App icon: build it once if missing, then bundle it.
[ -f "$ROOT/AppIcon.icns" ] || bash "$ROOT/scripts/build_icns.sh"
cp "$ROOT/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

swiftc -O -parse-as-library \
    "$ROOT/Sources/SleepState.swift" \
    "$ROOT/Sources/main.swift" \
    -o "$BIN_DIR/NoDoze"

# Ad-hoc sign so Gatekeeper lets the local build run.
codesign --force --sign - "$APP"

echo "Built $APP"
echo "Launch with:  open \"$APP\""
