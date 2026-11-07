#!/bin/bash
# Create a self-contained Linux installer script from the portable package.
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
. ./scripts/usb-environment.sh

PACKAGE="dist/Orvyn-portable-linux"
OUTPUT="dist/Orvyn-installer.sh"
if [ ! -d "$PACKAGE" ]; then
    echo "Error: portable package not found. Run ./scripts/package-portable.sh first." >&2
    exit 1
fi

mkdir -p dist
cat > "$OUTPUT" << 'INSTALLER'
#!/bin/bash
# Orvyn installer for Linux.
# Usage: ./Orvyn-installer.sh [--prefix DIR] [--yes] [--shortcut]
set -e

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/Orvyn-portable-linux"
PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}/orvyn"
ASSUME_YES=0
SHORTCUT=0

while [ $# -gt 0 ]; do
    case "$1" in
        --prefix) PREFIX="$2"; shift 2 ;;
        --prefix=*) PREFIX="${1#*=}"; shift ;;
        --yes|-y) ASSUME_YES=1; shift ;;
        --shortcut) SHORTCUT=1; shift ;;
        -h|--help)
            echo "Usage: $0 [--prefix DIR] [--yes] [--shortcut]"
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: portable package is missing next to this installer: $SOURCE_DIR" >&2
    exit 1
fi

if [ "$ASSUME_YES" -eq 0 ]; then
    read -r -p "Install Orvyn to $PREFIX? (y/n): " answer
    case "$answer" in y|Y|yes|YES) ;; *) echo "Installation cancelled."; exit 0 ;; esac
fi

mkdir -p "$PREFIX"
echo "Installing Orvyn to $PREFIX..."
cp -a "$SOURCE_DIR/orvyn-manager" "$PREFIX/"
cp -a "$SOURCE_DIR/apps" "$PREFIX/"
cp -a "$SOURCE_DIR/licenses" "$PREFIX/" 2>/dev/null || true

# Keep existing user configuration, conversations, models, and logs on update.
for dir in config data logs backups models runtime; do
    if [ -d "$PREFIX/$dir" ]; then
        echo "Preserving existing $dir/"
    elif [ -d "$SOURCE_DIR/$dir" ]; then
        cp -a "$SOURCE_DIR/$dir" "$PREFIX/"
    else
        mkdir -p "$PREFIX/$dir"
    fi
done
if [ -f "$SOURCE_DIR/README.txt" ]; then
    cp -a "$SOURCE_DIR/README.txt" "$PREFIX/"
fi

cat > "$PREFIX/start-orvyn.sh" << 'START'
#!/bin/bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_USB_CONFIG="$DIR/config/settings.json"
cd "$DIR"
exec ./orvyn-manager "$@"
START
chmod +x "$PREFIX/start-orvyn.sh"

if [ "$ASSUME_YES" -eq 0 ]; then
    read -r -p "Create an application menu shortcut? (y/n): " shortcut
    case "$shortcut" in y|Y|yes|YES) SHORTCUT=1 ;; esac
fi
if [ "$SHORTCUT" -eq 1 ]; then
    APPLICATIONS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
    mkdir -p "$APPLICATIONS"
    cat > "$APPLICATIONS/orvyn.desktop" << DESKTOP
[Desktop Entry]
Name=Orvyn
Comment=Portable AI workspace with chat and Opex Work
Exec=$PREFIX/start-orvyn.sh
Icon=$PREFIX/apps/web-ui/dist/orvyn-logo.png
Terminal=false
Type=Application
Categories=Utility;Development;
DESKTOP
    echo "Shortcut created: $APPLICATIONS/orvyn.desktop"
fi

echo "Orvyn installed. Start it with: $PREFIX/start-orvyn.sh"
INSTALLER
chmod +x "$OUTPUT"

echo "Installer created: $OUTPUT"
echo "Run it with: $OUTPUT"
