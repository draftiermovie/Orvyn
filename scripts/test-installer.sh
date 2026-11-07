#!/bin/bash
# Build the installer and install it into a temporary prefix.
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ ! -f dist/Orvyn-installer.sh ]; then
    echo "Installer not found. Building it first..."
    ./scripts/package-portable.sh
    ./scripts/build-installer.sh
fi

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "Installing into a temporary prefix..."
./dist/Orvyn-installer.sh --prefix "$TEMP_DIR/orvyn" --yes

for expected in orvyn-manager start-orvyn.sh config/settings.json apps/web-ui/dist/index.html; do
    if [ ! -e "$TEMP_DIR/orvyn/$expected" ]; then
        echo "Error: installed file is missing: $expected" >&2
        exit 1
    fi
done

echo "Installer test passed."
