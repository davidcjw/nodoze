#!/bin/bash
# Build NoDoze.app and package it as NoDoze.zip for a GitHub release.
# Uses ditto (not zip) so the ad-hoc code signature survives the round-trip.
# Prints the sha256 to paste into the Homebrew cask.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

bash "$ROOT/build.sh"

ZIP="$ROOT/NoDoze.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$ROOT/NoDoze.app" "$ZIP"

echo
echo "Created $ZIP"
echo "sha256: $(shasum -a 256 "$ZIP" | awk '{print $1}')"
