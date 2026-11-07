#!/bin/bash
set -euo pipefail

if [[ $(uname -s) != Darwin ]]; then
    echo 'Build the macOS package on a Mac.' >&2
    exit 1
fi

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"
arch=$(uname -m)
version=$(node -p 'require("./config/settings.example.json").app.version')
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
commit=$(git rev-parse HEAD)
binary=apps/manager/build-usb/release/ai-usb-manager
[[ -x $binary && -f apps/web-ui/dist/index.html ]]
lipo "$binary" -verify_arch "$arch"

mkdir -p dist
stage=$(mktemp -d "$root/dist/macos-${arch}.XXXXXX")
bundle="$stage/Orvyn.app"
contents="$bundle/Contents"
resources="$contents/Resources"
mkdir -p "$contents/MacOS" "$resources/config" "$resources/web" "$resources/licenses"
install -m 755 "$binary" "$contents/MacOS/Orvyn"
cp -R apps/web-ui/dist/. "$resources/web/"
cp -R apps/manager/packaging/licenses/. "$resources/licenses/"
cp config/model-catalog.example.json "$resources/config/model-catalog.json"
cp config/model-catalog.example.json "$resources/config/custom-models.json"
node - "$resources/config/settings.json" <<'NODE'
const fs = require('node:fs');
const settings = require('./config/settings.example.json');
settings.app.description = 'Orvyn for macOS';
settings.model_policy.default_model = '';
settings.paths.llamafile = 'runtime/llamafile/llamafile';
fs.writeFileSync(process.argv[2], JSON.stringify(settings, null, 2) + '\n');
NODE

cat > "$contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Orvyn</string>
    <key>CFBundleIdentifier</key><string>com.draftiermovie.orvyn</string>
    <key>CFBundleName</key><string>Orvyn</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$version</string>
    <key>CFBundleVersion</key><string>$version</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>NSAppTransportSecurity</key>
    <dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict>
</plist>
PLIST
printf '%s\n' "$commit" > "$resources/source-commit.txt"
plutil -lint "$contents/Info.plist"
codesign --force --sign - "$bundle"
codesign --verify --strict "$bundle"

archive="Orvyn-$version-macos-$arch-$commit.zip"
ditto -c -k --keepParent "$bundle" "dist/$archive"
(cd dist && shasum -a 256 "$archive" > "$archive.sha256")
if [[ -n ${GITHUB_OUTPUT:-} ]]; then
    printf 'bundle=%s\narchive=%s\n' "$bundle" "$archive" >> "$GITHUB_OUTPUT"
fi
printf 'App: %s\nArchive: %s\n' "$bundle" "$root/dist/$archive"
