#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP_PATH=${CODEX_RTL_HOST_APP:-/Applications/ChatGPT.app}
PORT=${CODEX_RTL_PORT:-9224}
NODE_BIN=${CODEX_RTL_NODE:-node}

case "$PORT" in
  ''|*[!0-9]*) echo "CODEX_RTL_PORT must be an integer." >&2; exit 2 ;;
esac

if [ "$PORT" -lt 1024 ] || [ "$PORT" -gt 65535 ]; then
  echo "CODEX_RTL_PORT must be between 1024 and 65535." >&2
  exit 2
fi

if [ ! -d "$APP_PATH" ] || [ ! -x "$APP_PATH/Contents/MacOS/ChatGPT" ]; then
  echo "ChatGPT.app was not found at: $APP_PATH" >&2
  exit 2
fi

if ! "$NODE_BIN" --version >/dev/null 2>&1; then
  echo "Node.js 22+ is required. Set CODEX_RTL_NODE if node is not on PATH." >&2
  exit 2
fi

NODE_MAJOR=$($NODE_BIN -p 'process.versions.node.split(".")[0]')
if [ "$NODE_MAJOR" -lt 22 ]; then
  echo "Node.js 22+ is required; found $($NODE_BIN --version)." >&2
  exit 2
fi

if ps -ax -o command= | grep -F -- "$APP_PATH/Contents/MacOS/ChatGPT" >/dev/null 2>&1; then
  echo "ChatGPT is already running. Close it yourself, then run this launcher again." >&2
  exit 1
fi

if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Port $PORT is already in use. Choose another CODEX_RTL_PORT." >&2
  exit 1
fi

echo "Opening ChatGPT with local DevTools on 127.0.0.1:${PORT}…"
nohup "$APP_PATH/Contents/MacOS/ChatGPT" \
  --remote-debugging-address=127.0.0.1 \
  --remote-debugging-port="$PORT" \
  >/dev/null 2>&1 &

echo "Waiting for a Codex renderer. Press Ctrl+C to stop the injector."
exec "$NODE_BIN" "$ROOT/inject.mjs" --port="$PORT" --watch
