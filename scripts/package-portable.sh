#!/bin/bash
# Stage a portable Linux package under dist/Orvyn-portable-linux.
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
. ./scripts/usb-environment.sh

TARGET="dist/Orvyn-portable-linux"

if [ ! -f dist/orvyn-manager ]; then
    echo "Error: dist/orvyn-manager is missing. Run ./scripts/deploy-desktop.sh first." >&2
    exit 1
fi
if [ ! -f apps/web-ui/dist/index.html ]; then
    echo "Error: the web UI bundle is missing. Run ./scripts/build-ui.sh first." >&2
    exit 1
fi

rm -rf "$TARGET"
mkdir -p "$TARGET"/{config,data,logs,backups,models,runtime/llamafile,apps/web-ui/dist,licenses}

cp dist/orvyn-manager "$TARGET/orvyn-manager"
chmod +x "$TARGET/orvyn-manager"
cp -a apps/web-ui/dist/. "$TARGET/apps/web-ui/dist/"

# Use the clean example configuration, never private user data.
for name in settings custom-models model-catalog; do
    source="config/$name.example.json"
    [ -f "$source" ] && cp "$source" "$TARGET/config/$name.json"
done

if [ -d apps/manager/packaging/licenses ]; then
    cp -a apps/manager/packaging/licenses/. "$TARGET/licenses/"
fi

if [ -f runtime/llamafile/llamafile ]; then
    cp runtime/llamafile/llamafile "$TARGET/runtime/llamafile/"
else
    echo "Note: runtime/llamafile/llamafile is not present; the package starts without local inference."
fi

if [ -f models/desktop-active/llama32-1b.gguf ]; then
    cp models/desktop-active/llama32-1b.gguf "$TARGET/models/"
    [ -f models/desktop-active/llama32-1b.gguf.verified.json ] &&
        cp models/desktop-active/llama32-1b.gguf.verified.json "$TARGET/models/"
fi

cat > "$TARGET/start-orvyn.sh" << 'SCRIPT'
#!/bin/bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_USB_CONFIG="$DIR/config/settings.json"
cd "$DIR"
exec ./orvyn-manager "$@"
SCRIPT
chmod +x "$TARGET/start-orvyn.sh"

cat > "$TARGET/README.txt" << 'TXT'
Orvyn Portable - Linux
======================

Start: ./start-orvyn.sh

Keep this folder together. Configuration, conversations, models, logs, and
backups stay inside the folder. If runtime/llamafile/llamafile and a compatible
GGUF model are present, local inference can be used; otherwise connect an
OpenAI-compatible API in Settings.

The Linux build uses the system WebKitGTK WebView. Install the WebKitGTK 4.1
runtime and the usual GTK libraries through your distribution's package manager.

Orvyn application source and documentation are covered by the Orvyn Free
Redistribution License 1.0. Model weights, llamafile, and other dependencies
keep their own licenses; see the licenses folder.
TXT

echo "Portable package staged: $TARGET"
echo "Start it with: $TARGET/start-orvyn.sh"
