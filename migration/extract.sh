#!/usr/bin/env bash
set -euo pipefail

PROG="$(basename "$0")"

log() {
    echo "[$PROG] $1"
}

log "Starting data extraction process"

if [[ "$#" -eq 0 ]]; then
    log "ERROR: No arguments provided."
    log "Usage:"
    log "  $PROG -a"
    log "    # Extract all object types (authenticators, search_providers, ai_providers)"
    log ""
    log "  $PROG authenticators search_providers [-n '<name-regex>']"
    log "    # Extract only selected object types, optionally filtered by name"
    exit 1
fi

log "Starting data model object extraction with args: $*"

# Adjust filename here if your extractor is named differently (e.g. extract_objects.py)
PYTHONPATH=. python ./migration/extract.py "$@"

log "Completed data model object extraction."
