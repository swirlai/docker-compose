#!/bin/bash

####
# Destroys the SWIRL docker containers and DB volumes with extreme prejudice.
# This is most handy for starting fresh after something has gone wrong.
####

set -euo pipefail

PROG=`basename "$0"`

# Logging function
function log() {
    echo "[$(date +%Y-%m-%dT%H:%M:%S) ${PROG}] $1"
}

# Error logging function
function error() {
    echo "[$(date +%Y-%m-%dT%H:%M:%S) ${PROG} ERROR] $1"
}


# Resolve paths relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

DOCKER_BIN="$(command -v docker)"

log "Using compose file: $PARENT_DIR/docker-compose.yml"

log "Bringing down all SWIRL services (compose --profile all down)..."
"$DOCKER_BIN" compose -f "$PARENT_DIR/docker-compose.yml" --profile all down

log "Removing swirl_db_data volume (if it exists)..."
"$DOCKER_BIN" volume rm -f swirl_db_data || true

log "Showing any remaining containers with 'swirl' in the name:"
"$DOCKER_BIN" ps -a --filter "name=swirl"

log "Removing SWIRL flag files..."
rm -f "$PARENT_DIR"/.swirl-*.flag || true

log "Done."
