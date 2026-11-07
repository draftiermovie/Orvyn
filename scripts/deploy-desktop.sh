#!/bin/bash
# Copy the release build into the repository dist/ folder.
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
. ./scripts/usb-environment.sh

BINARY="$CARGO_TARGET_DIR/release/ai-usb-manager"
if [ ! -f "$BINARY" ]; then
    echo "Error: release build not found. Run ./scripts/build-desktop.sh first." >&2
    exit 1
fi

mkdir -p dist
cp "$BINARY" dist/orvyn-manager
chmod +x dist/orvyn-manager

echo "Desktop deployed: dist/orvyn-manager"
