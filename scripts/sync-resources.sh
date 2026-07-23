#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
DESTINATION="$ROOT/Sources/CodexRTLCore/Resources"

mkdir -p "$DESTINATION"
cp "$ROOT/src/direction.js" "$DESTINATION/direction.js"
cp "$ROOT/src/rtl-runtime.js" "$DESTINATION/rtl-runtime.js"
cp "$ROOT/src/rtl-style.css" "$DESTINATION/rtl-style.css"
