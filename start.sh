#!/bin/sh

# Starts this local RTL tool through its existing launcher.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

case "$ROOT" in
  /|/Users|"$HOME"|"$HOME/Documents"|"$HOME/Desktop"|"$HOME/Downloads")
    echo "Refusing to start from an unsafe directory: $ROOT" >&2
    exit 2
    ;;
esac

if [ ! -f "$ROOT/run.sh" ] || [ ! -f "$ROOT/inject.mjs" ] || [ ! -f "$ROOT/src/rtl-runtime.js" ]; then
  echo "This directory does not contain a complete local Codex RTL tool: $ROOT" >&2
  exit 2
fi

exec sh "$ROOT/run.sh"
