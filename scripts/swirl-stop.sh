#!/bin/bash
####
# Stop SWIRL application directly in docker AND through system services (LaunchAgent/systemd).
# This is done mainly to account for asymmetry in how DARWIN services handle docker and signals
####

set -e

# Resolve paths relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

DOCKER_BIN="$(command -v docker)"

echo "[swirl-stop] Stopping Swirl Docker stack..."
"$DOCKER_BIN" compose -f "$PARENT_DIR/docker-compose.yml" --profile all stop || true

if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "[swirl-stop] Unloading LaunchAgent com.swirl.service..."
    launchctl stop "gui/$(id -u)/com.swirl.service" || true
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "[swirl-stop] Stopping systemd service swirl.service..."
    sudo systemctl stop swirl.service || true
fi

echo "[swirl-stop] Done."
