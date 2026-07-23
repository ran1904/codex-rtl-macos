#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
ARCHIVE="$ROOT/dist/Codex-RTL-Helper.zip"
TARGET_ROOT="$HOME/Applications"
TARGET="$TARGET_ROOT/Codex RTL Helper.app"
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/codex-rtl-install.XXXXXX")

cleanup() {
    rm -rf "$STAGE"
}
trap cleanup EXIT

if [ ! -f "$ARCHIVE" ]; then
    echo "Build the app first with: sh ./scripts/build-app.sh" >&2
    exit 1
fi

ditto -x -k "$ARCHIVE" "$STAGE"
SOURCE="$STAGE/Codex RTL Helper.app"
codesign --verify --deep --strict --verbose=2 "$SOURCE"

mkdir -p "$TARGET_ROOT"
if [ -e "$TARGET" ]; then
    TRASH_ROOT="$HOME/.Trash"
    TRASH_TARGET="$TRASH_ROOT/Codex RTL Helper-$(date '+%Y%m%d-%H%M%S')-$$.app"
    mkdir -p "$TRASH_ROOT"
    mv "$TARGET" "$TRASH_TARGET"
fi
ditto --noextattr --noqtn "$SOURCE" "$TARGET"
codesign --verify --deep --strict --verbose=2 "$TARGET"

echo "$TARGET"
