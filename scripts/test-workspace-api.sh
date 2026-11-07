#!/bin/bash
# Run the TypeScript and browser integration checks.
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
. ./scripts/usb-environment.sh

if [ ! -d apps/web-ui/node_modules ]; then
    echo "Error: web UI dependencies are missing. Run ./scripts/build-ui.sh first." >&2
    exit 1
fi

echo "Running the TypeScript type check..."
node apps/web-ui/node_modules/typescript/bin/tsc --project apps/web-ui/tsconfig.json --noEmit --incremental false

echo "Running the chat client test..."
node tests/chat-client.mjs

echo "Running the workspace UI test..."
node tests/workspace-ui.mjs

echo "Running the Opex Work UI test..."
node tests/opex-work-ui.mjs

echo "All workspace tests passed."
