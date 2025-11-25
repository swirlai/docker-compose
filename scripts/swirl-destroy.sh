#!/bin/bash
set -euo pipefail

# Resolve paths relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

DOCKER_BIN="$(command -v docker)"

echo "[destroy] Using compose file: $PARENT_DIR/docker-compose.yml"

echo "[destroy] Bringing down all Swirl services (compose --profile all down)..."
"$DOCKER_BIN" compose -f "$PARENT_DIR/docker-compose.yml" --profile all down

echo "[destroy] Removing swirl_db_data volume (if it exists)..."
"$DOCKER_BIN" volume rm -f swirl_db_data || true

echo "[destroy] Showing any remaining containers with 'swirl' in the name:"
"$DOCKER_BIN" ps -a --filter "name=swirl"

echo "[destroy] Removing Swirl flag files..."
rm -f "$PARENT_DIR"/.swirl-*.flag || true

echo "[destroy] Done."
