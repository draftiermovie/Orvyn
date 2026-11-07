#!/bin/bash
# Run the Rust unit tests for the manager.
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
. ./scripts/usb-environment.sh

cargo test \
    --manifest-path apps/manager/Cargo.toml \
    --release \
    --locked \
    --target-dir "$CARGO_TARGET_DIR" \
    -- --test-threads=2

echo "Manager tests completed."
