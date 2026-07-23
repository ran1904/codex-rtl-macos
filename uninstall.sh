#!/bin/sh

# Removes only this local RTL tool. It never changes ChatGPT.app.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
ASSUME_YES=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: sh ./uninstall.sh [--yes] [--dry-run]

  --yes      Skip the confirmation prompt.
  --dry-run  Show what would happen without quitting ChatGPT or moving files.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --yes) ASSUME_YES=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

# Do not turn a mistaken invocation from a broad directory into a destructive action.
case "$ROOT" in
  /|/Users|"$HOME"|"$HOME/Documents"|"$HOME/Desktop"|"$HOME/Downloads")
    echo "Refusing to remove an unsafe directory: $ROOT" >&2
    exit 2
    ;;
esac

# Require the distinctive files of this tool before acting on its directory.
if [ ! -f "$ROOT/inject.mjs" ] || [ ! -f "$ROOT/run.sh" ] || [ ! -f "$ROOT/stop.sh" ] || [ ! -f "$ROOT/src/rtl-runtime.js" ]; then
  echo "Refusing to remove $ROOT because it does not look like the local Codex RTL tool." >&2
  exit 2
fi

if [ "$DRY_RUN" -eq 1 ]; then
  sh "$ROOT/stop.sh" --dry-run
  echo "Would move this tool folder to Trash: $ROOT"
  exit 0
fi

if [ "$ASSUME_YES" -ne 1 ]; then
  printf 'This will quit ChatGPT, stop this RTL injector, and move this folder to Trash:\n  %s\nContinue? [y/N] ' "$ROOT"
  IFS= read -r answer || answer=''
  case "$answer" in
    y|Y|yes|YES) ;;
    *) echo "Cancelled."; exit 0 ;;
  esac
fi

sh "$ROOT/stop.sh" --yes

TRASH_ROOT="$HOME/.Trash"
TRASH_TARGET="$TRASH_ROOT/$(basename "$ROOT")-$(date '+%Y%m%d-%H%M%S')-$$"
mkdir -p "$TRASH_ROOT"
mv "$ROOT" "$TRASH_TARGET"
echo "Moved the local Codex RTL tool to Trash: $ROOT"
