#!/bin/bash
# Build the Rust desktop host for Linux.
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
. ./scripts/usb-environment.sh

if ! command -v cargo >/dev/null 2>&1; then
    echo "Error: cargo could not be found. Install Rust from https://rustup.rs." >&2
    exit 1
fi

echo "Rust toolchain: $(rustc --version)"
echo "Building the desktop application..."
cargo build \
    --manifest-path apps/manager/Cargo.toml \
    --release \
    --locked \
    --target-dir "$CARGO_TARGET_DIR"

echo "Desktop build complete: apps/manager/build-usb/release/ai-usb-manager"
