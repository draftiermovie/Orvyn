#!/bin/bash
# Install the web UI dependencies and build the desktop bundle.
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
. ./scripts/usb-environment.sh

cd apps/web-ui
if [ ! -d node_modules ] || [ package-lock.json -nt node_modules/.package-lock.json ]; then
    echo "Installing npm dependencies..."
    npm ci
fi
echo "Building the desktop web bundle..."
node build-desktop.mjs

echo "UI build complete: apps/web-ui/dist"
