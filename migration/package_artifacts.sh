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

FROM="${1:-}"
TO="${2:-}"

if [[ -z "${FROM}" || -z "${TO}" ]]; then
    error "Usage: $0 FROM_VERSION TO_VERSION (e.g. v4_0_0_0 v4_4_0_0)"
fi

# Assume script is run from /app
# cd /app

MIGRATION_DIR="./migration"
if [[ ! -d "${MIGRATION_DIR}" ]]; then
    error "Migration directory ${MIGRATION_DIR} not found."
fi

TIMESTAMP="$(date +%Y-%m-%d-%H%M%S)"
BUNDLE_NAME="migration_bundle_${FROM}_to_${TO}_${TIMESTAMP}.tar.gz"
BUNDLE_PATH="./${BUNDLE_NAME}"   # bundle lives in /app

log "Creating migration bundle: ${BUNDLE_PATH}"

# Optional sanity checks (warn, don't fail)
if [[ ! -f "${MIGRATION_DIR}/extract.json" ]]; then
    log "WARNING: ${MIGRATION_DIR}/extract.json not found – did extract run?"
fi

# Archive the migration directory itself into a tarball in /app
# This will create a bundle that, when extracted, contains a top-level "migration/" directory.
tar czf "${BUNDLE_PATH}" migration

log "Migration bundle created: ${BUNDLE_PATH}"
log "You can now copy this single file to the new VM (e.g. scp ${BUNDLE_NAME})."
