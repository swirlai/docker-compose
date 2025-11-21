#!/bin/bash
set -e

# Resolve paths relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

DOCKER_BIN="$(command -v docker)"

echo "[swirl-stop] Stopping Swirl Docker stack..."
"$DOCKER_BIN" compose -f "$PARENT_DIR/docker-compose.yml" --profile all stop || true

if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "[swirl-stop] Unloading LaunchAgent com.swirl.service..."
    launchctl bootout "gui/$(id -u)/com.swirl.service" || true
fi

echo "[swirl-stop] Done."
