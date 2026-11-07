#!/bin/bash
# Start Orvyn from the deployed dist/ build.
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ ! -f config/settings.json ]; then
    echo "Configuration not found. Initializing..."
    ./scripts/init-config.sh
fi
. ./scripts/usb-environment.sh

if [ ! -f dist/orvyn-manager ]; then
    echo "Error: dist/orvyn-manager is missing. Run ./scripts/build-desktop.sh and ./scripts/deploy-desktop.sh." >&2
    exit 1
fi

echo "Starting Orvyn..."
exec ./dist/orvyn-manager "$@"
