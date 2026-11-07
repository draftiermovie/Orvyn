#!/bin/bash
# Set up the repository-local build environment for Linux.
# Source this file: . ./scripts/usb-environment.sh

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USB_ROOT="$(dirname "$_script_dir")"

if [ ! -f "$USB_ROOT/config/settings.json" ]; then
    echo "USB project configuration is missing: $USB_ROOT/config/settings.json" >&2
    echo "Run ./scripts/init-config.sh first." >&2
    return 1 2>/dev/null || exit 1
fi

TEMP="$USB_ROOT/tools/tmp"
TMP="$USB_ROOT/tools/tmp"
CARGO_HOME="$USB_ROOT/tools/cache/cargo"
CARGO_TARGET_DIR="$USB_ROOT/apps/manager/build-usb"
npm_config_cache="$USB_ROOT/tools/cache/npm"
BUN_INSTALL_CACHE_DIR="$USB_ROOT/tools/cache/bun"

mkdir -p "$TEMP" "$TMP" "$CARGO_HOME" "$CARGO_TARGET_DIR" "$npm_config_cache" "$BUN_INSTALL_CACHE_DIR"

export USB_ROOT TEMP TMP CARGO_HOME CARGO_TARGET_DIR npm_config_cache BUN_INSTALL_CACHE_DIR
export AI_USB_CONFIG="$USB_ROOT/config/settings.json"

echo "USB environment set up successfully"
echo "  UsbRoot: $USB_ROOT"
echo "  AI_USB_CONFIG: $AI_USB_CONFIG"
echo "  CARGO_HOME: $CARGO_HOME"
echo "  CARGO_TARGET_DIR: $CARGO_TARGET_DIR"
