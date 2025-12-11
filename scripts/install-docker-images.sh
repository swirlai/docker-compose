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

# Check for local SWIRL image (for diagnostics only)
if "${DOCKER_BIN}" inspect "${SWIRL_PATH}:${SWIRL_VERSION}" > /dev/null 2>&1; then
    log "Found local SWIRL image ${SWIRL_PATH}:${SWIRL_VERSION}"
else
    log "Local SWIRL image ${SWIRL_PATH}:${SWIRL_VERSION} not found locally."
fi

ACTIVE_PROFILES="$(get_active_profiles)"
log "Pulling images from Docker Hub for profiles: ${ACTIVE_PROFILES:-<none>}"

COMPOSE_PROFILES="${ACTIVE_PROFILES}" \
    "${DOCKER_BIN}" compose -f "$PARENT_DIR/docker-compose.yml" pull --quiet

log "Docker image installation completed."
