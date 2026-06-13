#!/bin/bash
# Compile and run the SleepState unit tests.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

swiftc -parse-as-library \
    "$ROOT/Sources/SleepState.swift" \
    "$ROOT/tests/SleepStateTests.swift" \
    -o "$TMP/tests"

"$TMP/tests"
