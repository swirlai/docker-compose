#!/usr/bin/env bash
set -euo pipefail

PROG="$(basename "$0")"

log() {
    echo "[$PROG] $1"
}

error() {
    echo "[$PROG] ERROR: $1" >&2
    exit 1
}

log "Starting file copy process"

# Timestamp for backup names
TIMESTAMP="$(date +%Y-%m-%d-%H%M%S)"

# Base migration directory (relative to current working directory)
MIGRATION_DIR="./migration"

# Ensure migration directory exists
if [[ ! -d "$MIGRATION_DIR" ]]; then
    log "Creating migration directory: $MIGRATION_DIR"
    mkdir -p "$MIGRATION_DIR"
fi

########################################
# 1. Copy .env to migration/env_<timestamp>.bak
########################################

ENV_SRC="./.env"
ENV_DST="${MIGRATION_DIR}/env_${TIMESTAMP}.bak"

if [[ -f "$ENV_SRC" ]]; then
    log "Copying $ENV_SRC to $ENV_DST"
    cp "$ENV_SRC" "$ENV_DST"
    log "Environment file backup created: $ENV_DST"
else
    error "Environment file $ENV_SRC not found. Run this script from the directory containing .env."
fi

########################################
# 2. Copy certificates to migration/certs_<timestamp>
########################################

CERTS_SRC="./nginx/certificates"
CERTS_DST="${MIGRATION_DIR}/certs_${TIMESTAMP}"

if [[ -d "$CERTS_SRC" ]]; then
    log "Copying certificates from $CERTS_SRC to $CERTS_DST"
    mkdir -p "$CERTS_DST"
    cp -a "${CERTS_SRC}/." "$CERTS_DST/"
    log "Certificate backup created at: $CERTS_DST"
else
    log "No certificate directory found at $CERTS_SRC – skipping certificate backup."
fi

log "File copy process completed successfully."
