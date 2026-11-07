# Orvyn development recipes (Linux).
# Run `just` to list the available recipes.

set shell := ["bash", "-c"]

root := justfile_directory()

# Show the available recipes.
default:
    @just --list

# Create config/settings.json from the example.
init:
    ./scripts/init-config.sh

# Install web UI dependencies and build the desktop bundle.
ui:
    ./scripts/build-ui.sh

# Build the Rust manager for Linux.
desktop:
    ./scripts/build-desktop.sh

# Copy the release build into dist/.
deploy:
    ./scripts/deploy-desktop.sh

# Build the UI, the desktop binary, and deploy it.
build: ui desktop deploy

# Run Orvyn from dist/.
run:
    ./scripts/start-all.sh

# Stage the portable Linux package.
package: deploy
    ./scripts/package-portable.sh

# Build the Linux installer.
installer: package
    ./scripts/build-installer.sh

# Remove generated Linux build output.
clean:
    rm -rf apps/manager/build-usb dist/Orvyn-portable-linux dist/Orvyn-installer.sh dist/orvyn-manager
