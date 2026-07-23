#!/bin/sh

# Stops the active local RTL session while keeping this tool folder intact.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
ASSUME_YES=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: sh ./stop.sh [--yes] [--dry-run]

  --yes      Skip the confirmation prompt.
  --dry-run  Show what would happen without closing ChatGPT.
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

case "$ROOT" in
  /|/Users|"$HOME"|"$HOME/Documents"|"$HOME/Desktop"|"$HOME/Downloads")
    echo "Refusing to operate from an unsafe directory: $ROOT" >&2
    exit 2
    ;;
esac

if [ ! -f "$ROOT/inject.mjs" ] || [ ! -f "$ROOT/run.sh" ] || [ ! -f "$ROOT/src/rtl-runtime.js" ]; then
  echo "Refusing to stop $ROOT because it does not look like the local Codex RTL tool." >&2
  exit 2
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Would stop the injector launched from: $ROOT"
  echo "Would quit ChatGPT to remove the temporary RTL layer."
  echo "This tool folder would remain available to run again."
  exit 0
fi

if [ "$ASSUME_YES" -ne 1 ]; then
  printf 'This will quit ChatGPT and stop the active RTL injector. The tool folder stays installed.\nContinue? [y/N] '
  IFS= read -r answer || answer=''
  case "$answer" in
    y|Y|yes|YES) ;;
    *) echo "Cancelled."; exit 0 ;;
  esac
fi

# Match only an injector whose command line includes this exact tool directory.
injector_pids=$(ps -ax -o pid= -o command= | awk -v needle="$ROOT/inject.mjs" 'index($0, needle) { print $1 }')
if [ -n "$injector_pids" ]; then
  kill $injector_pids 2>/dev/null || true
fi

# The visual changes and local DevTools port live only for the launched ChatGPT session.
osascript -e 'tell application "ChatGPT" to quit' >/dev/null 2>&1 || true

attempt=0
while pgrep -x ChatGPT >/dev/null 2>&1 && [ "$attempt" -lt 10 ]; do
  sleep 1
  attempt=$((attempt + 1))
done

if pgrep -x ChatGPT >/dev/null 2>&1; then
  echo "ChatGPT did not close. Close it fully, then run this script again." >&2
  exit 1
fi

echo "The local Codex RTL session was stopped. Run sh ./run.sh to enable it again."
