#!/bin/bash
####
# Main installation script for SWIRL application. Sets up environment, installs dependencies, and configures services.
####

set -e

PROG=`basename "$0"`

# Logging function
function log() {
    echo "[$(date +%Y-%m-%dT%H:%M:%S) ${PROG}] $1"
}

# Error logging function
function error() {
    echo "[$(date +%Y-%m-%dT%H:%M:%S) ${PROG} ERROR] $1"
}

# Get our location in the file system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log "Script directory: $SCRIPT_DIR"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
log "Parent directory: $PARENT_DIR"

# Find full path to Docker binary
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export DOCKER_BIN="$(command -v docker)"

log "This script will require Sudo at several points you will be prompted for admin creds."

# Load environment variables from .env
ENV_FILE="$PARENT_DIR/.env"
log "Loading env file $ENV_FILE and sourcing shared functions..."
source "$ENV_FILE"
source "$PARENT_DIR/scripts/swirl-shared.sh"

# check for local images and pull if not found
if "${DOCKER_BIN}" inspect "${SWIRL_PATH}:${SWIRL_VERSION}" > /dev/null 2>&1; then
    log "Found local SWIRL image ${SWIRL_PATH}:${SWIRL_VERSION}"
else
    log "Local SWIRL image ${SWIRL_PATH}:${SWIRL_VERSION} not found. Pulling images from Docker Hub."
    log "Pulling for profiles: $(get_active_profiles)"
    COMPOSE_PROFILES="$(get_active_profiles)" "${DOCKER_BIN}" compose -f $PARENT_DIR/docker-compose.yml  pull --quiet
fi

log "Docker image Installation completed."