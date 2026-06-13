#!/bin/bash
# Render docs/demo.gif from the real PopoverContent UI (ImageRenderer + ImageIO).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

swiftc -parse-as-library \
    "$ROOT/Sources/SleepState.swift" \
    "$ROOT/Sources/PopoverContent.swift" \
    "$ROOT/scripts/make_demo_gif.swift" \
    -o "$TMP/demo"

mkdir -p "$ROOT/docs"
( cd "$TMP" && "$TMP/demo" "$ROOT/docs/demo.gif" )
# the renderer drops per-frame PNGs in CWD; clean them from TMP (auto-removed)
echo "Wrote $ROOT/docs/demo.gif"
