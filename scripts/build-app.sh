#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
APP_NAME="Codex RTL Helper.app"
BUILD_DIR="$ROOT/.build/release"
STAGE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/codex-rtl-build.XXXXXX")
APP_DIR="$STAGE_DIR/$APP_NAME"
DESTINATION="$ROOT/dist/$APP_NAME"
ARCHIVE="$ROOT/dist/Codex-RTL-Helper.zip"

cleanup() {
    rm -rf "$STAGE_DIR"
}
trap cleanup EXIT

cd "$ROOT"
sh "$ROOT/scripts/sync-resources.sh"
swift build -c release

rm -rf "$STAGE_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$ROOT/dist"

cp "$BUILD_DIR/Codex-RTL-Helper" "$APP_DIR/Contents/MacOS/Codex-RTL-Helper"
cp "$ROOT/packaging/Info.plist" "$APP_DIR/Contents/Info.plist"

RESOURCE_BUNDLE=$(find -L "$BUILD_DIR" -maxdepth 1 -type d -name '*CodexRTL*.bundle' -print -quit)
if [ -z "$RESOURCE_BUNDLE" ]; then
    echo "SwiftPM resource bundle was not found in $BUILD_DIR" >&2
    exit 1
fi
cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/"

plutil -lint "$APP_DIR/Contents/Info.plist"
xattr -cr "$APP_DIR"
codesign --force --sign - "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

rm -rf "$DESTINATION"
ditto --noextattr --noqtn "$APP_DIR" "$DESTINATION"
xattr -cr "$DESTINATION"
codesign --verify --deep --strict --verbose=2 "$DESTINATION"
rm -f "$ARCHIVE"
ditto -c -k --keepParent --norsrc "$APP_DIR" "$ARCHIVE"

echo "$DESTINATION"
echo "$ARCHIVE"
