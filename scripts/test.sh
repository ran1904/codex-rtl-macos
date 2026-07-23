#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)

sh "$ROOT/scripts/sync-resources.sh"
cd "$ROOT"
swift run Codex-RTL-SelfTest
